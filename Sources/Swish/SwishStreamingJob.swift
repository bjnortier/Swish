//
//  SwishStreamingJob.swift
//  Swish
//
//  Created by Ben Nortier on 2025/05/26.
//

import Foundation

// The number of samples to have received to do a transcription
private let minSamplesSize = WhisperConstants.samplingFrequency / 10
// The number of samples to have transcribed before moving onto the next frame
private let frameSize = 29 * WhisperConstants.samplingFrequency
// The number of sample to use as an overlap between frames to alleviate missed words
private let overlapSize = 800

@MainActor
public class SwishStreamingJob: SwishJob {
    var streamingEngine: SwishStreamingEngine
    var bufferActor: SwishBufferActor

    public init(
        state: State = .created,
        acc: SwishAccumulator = .init(),
        streamingEngine: SwishStreamingEngine
    ) {
        self.streamingEngine = streamingEngine
        self.bufferActor = SwishBufferActor(
            minSamplesSize: minSamplesSize,
            frameSize: frameSize,
            overlapSize: overlapSize
        )
        super.init(state: state, acc: acc)
    }


    public func start(options: SwishJob.Options) -> Task<Void, Error> {
        let task = Task(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }


            do {
                let transcriber = try await self.createOrReuseTranscriber(options: options)

                self.setState(.busy)
                try self.streamingEngine.startStreaming(bufferActor: self.bufferActor)

                while true {
                    if Task.isCancelled, self.state == .cancelling {
                        break
                    }

                    let (nextSamples, isFrame) = await self.bufferActor.getNextSamples()
                    if Task.isCancelled, self.state == .stopping, nextSamples == nil {
                        break
                    }

                    // Transcribe if enough samples have been received
                    if let nextSamples, self.state != .paused {
                        let localAccumulator = SwishAccumulator(stopAccumulating: self.acc.stopAccumulating)
                        try await transcriber.transcribe(
                            samples: nextSamples,
                            acc: localAccumulator,
                            audioLanguage: options.audioLanguage,
                            translateToEN: options.translateToEN,
                            tokenTimestamps: options.tokenTimestamps,
                            maxSegmentTokens: options.maxSegmentTokens,
                            beamSize: options.beamSize
                        )

                        // Append the segments to the main job accumulator
                        let localSegments = localAccumulator.segments
                        if localSegments.count > 0 {
                            self.acc.appendAtHighWaterMark(localSegments, updateMark: isFrame)
                        }
                        // This prevents memory use rising over time but not sure why :/
                        await Task.yield()
                    } else {
                        try await Task.sleep(nanoseconds: 100_000_000)
                    }
                }
            } catch is CancellationError {
                // Can result in a CancellationError if the Task is cancelled during sleep,
                // ignore if that happens
            } catch {
                throw error
            }

            if self.state == .cancelling {
                self.setState(.cancelled)
            } else if self.state != .restarting {
                // Should be set in start() Task but could be a race condition and task already finished
                self.setState(.done)
            }
            self.destroyTranscriber()
        }
        self.task = task
        return task
    }

    public func stop() -> Task<Void, Error> {
        Task(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            guard let task = self.task else {
                throw SwishError.jobNotStarted
            }
            try self.streamingEngine.stopStreaming()
            self.setState(.stopping)
            self.acc.stopAccumulating = true
            task.cancel()
            try await task.value
            self.setState(.done)
        }
    }

    public func cancel(forRestart: Bool = false) -> Task<Void, Error> {
        Task(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            guard let task = self.task else {
                throw SwishError.jobNotStarted
            }
            try self.streamingEngine.stopStreaming()
            if forRestart {
                self.setState(.restarting)
            } else {
                self.setState(.cancelling)
            }
            self.acc.stopAccumulating = true
            task.cancel()
            try await task.value
        }
    }

    public func restart(options: SwishJob.Options) -> Task<Void, Error> {
        Task(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            try await self.cancel(forRestart: true).value
            self.acc.reset()
            await self.bufferActor.reset(clearBuffer: false)
            _ = self.start(options: options)
        }
    }

    public func pause() -> Task<Void, Error> {
        Task(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            try self.streamingEngine.pauseStreaming()
            self.setState(.paused)
        }
    }

    public func unpause() -> Task<Void, Error> {
        Task(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            try self.streamingEngine.unpauseStreaming()
            self.setState(.busy)
        }
    }

    public func clear() -> Task<Void, Error> {
        Task(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            await self.bufferActor.reset(clearBuffer: true)
            self.acc.reset()
        }
    }
}
