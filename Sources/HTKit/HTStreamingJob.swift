//
//  HTStreamingJob.swift
//  HTKit
//
//  Created by Ben Nortier on 2025/05/26.
//

import Foundation

// The number of samples to have received to do a transcription
private let minSamplesSize = WhisperConstants.samplingFrequency / 10
// The number of samples to have transcribed before moving onto the next frame
private let frameSize = 29 * WhisperConstants.samplingFrequency
// The number of samples to use as an overlap between frames to alleviate missed words
private let overlapSize = 800

public class HTStreamingJob: HTJob {
    var streamingEngine: HTStreamingEngine
    var audioBuffer: HTStreamingAudioBuffer

    public init(
        streamingEngine: HTStreamingEngine
    ) {
        self.streamingEngine = streamingEngine
        self.audioBuffer = HTStreamingAudioBuffer(
            minSamplesSize: minSamplesSize,
            frameSize: frameSize,
            overlapSize: overlapSize
        )
        super.init()
    }

    public func start(
        modelPath: String,
        options: HTTranscriber.Options = .init()
    ) -> Task<Void, Error> {
        let task = Task(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            do {
                try await self.transcribe(modelPath: modelPath, options: options)
                self.setState(.done)
            } catch {
                self.setState(.error, error: error)
                throw error
            }
        }
        self.task = task
        return task
    }

    public func stop() async throws {
        guard let task = self.task else {
            throw HTError.jobNotStarted
        }
        try self.streamingEngine.stopStreaming()

        self.setState(.stopping)
        self.abortController.stop()
        task.cancel()
        try await task.value

        self.setState(.done)
    }

    public func restart(
        modelPath: String,
        options: HTTranscriber.Options = .init()
    ) async throws -> Task<Void, Error> {
        guard let task = self.task else {
            throw HTError.jobNotStarted
        }

        self.setState(.restarting)
        self.abortController.stop()
        task.cancel()
        try await task.value

        self.transcription.reset()
        self.abortController.reset()
        await self.audioBuffer.reset()

        return self.start(modelPath: modelPath, options: options)

    }

    public func pause() async throws {
        try self.streamingEngine.pauseStreaming()
        self.setState(.paused)
    }

    public func unpause() async throws {
        try self.streamingEngine.unpauseStreaming()
        self.setState(.transcribing)
    }

    public func clear() async throws {
        await self.audioBuffer.clear()
        self.transcription.reset()
    }

    func transcribe(modelPath: String, options: HTTranscriber.Options = .init()) async throws {
        do {
            let transcriber = try await self.createOrReuseTranscriber(modelPath: modelPath)
            try self.streamingEngine.startStreaming(buffer: self.audioBuffer)

            self.setState(.transcribing)
            while true {
                // Cancel immediately
                if Task.isCancelled, self.state == .cancelling {
                    break
                }

                // When stopping, finish the samples in the buffer
                let (nextSamples, isFrame) = await self.audioBuffer.getNextSamples()
                if Task.isCancelled, self.state == .stopping, nextSamples == nil {
                    break
                }

                // Transcribe if enough samples have been received
                if let nextSamples, self.state != .paused {
                    // Use a local transcriptions as it will be overritten by
                    // new samples withint the same 30-sec frame
                    let localTranscription = HTTranscription()
                    try await transcriber.transcribe(
                        samples: nextSamples,
                        transcription: localTranscription,
                        abortController: abortController,
                        options: options
                    )

                    // Append the segments to the main job accumulator
                    let localSegments = localTranscription.segments
                    if localSegments.count > 0 {
                        self.transcription.appendAtHighWaterMark(localSegments, updateMark: isFrame)
                    }
                    // Explicity yield to allow other tasks to run
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
    }

}
