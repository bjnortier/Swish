//
//  SwishFullJob.swift
//  Swish
//
//  Created by Ben Nortier on 2025/05/22.
//

import Foundation
import os

@MainActor
public class SwishFullJob: SwishJob {
    public typealias Preprocessor = () async throws -> [Float]

    private var samples: [Float]?
    private var preprocessor: Preprocessor?

    public init(
        state: SwishJob.State = .created,
        acc: SwishAccumulator = .init(),
        samples: [Float]
    ) {
        self.samples = samples
        super.init(state: state, acc: acc)
    }

    public init(
        state: State = .created,
        acc: SwishAccumulator = .init(),
        preprocessor: @escaping Preprocessor
    ) {
        self.preprocessor = preprocessor
        super.init(state: state, acc: acc)
    }

    public func start(options: SwishJob.Options) -> Task<Void, Error> {
        let task = Task(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }

            do {

                // Get samples using preprocessor or if set in initialiser
                let samples = try await self.getSamples()

                // see createOrReuseTranscriber() for side-effects
                let transcriber = try await self.createOrReuseTranscriber(options: options)

                await MainActor.run { self.setState(.busy) }
                _ = try await transcriber.transcribe(
                    samples: samples,
                    acc: self.acc,
                    audioLanguage: options.audioLanguage,
                    translateToEN: options.translateToEN,
                    tokenTimestamps: options.tokenTimestamps,
                    maxSegmentTokens: options.maxSegmentTokens,
                    beamSize: options.beamSize
                )

                await MainActor.run {
                    if self.state == .cancelling {
                        self.setState(.cancelled)
                    } else if self.state != .restarting {
                        self.setState(.done)
                    }
                    self.destroyTranscriber()
                }

            } catch {
                await MainActor.run {
                    self.setState(.error, error: error)
                }
                throw error
            }
        }
        self.task = task
        return task
    }

    private func getSamples() async throws -> [Float] {
        if let preprocessor {
            await MainActor.run { setState(.preprocessing) }
            return try await preprocessor()
        } else {
            return samples!
        }
    }

    public func restart(options: SwishJob.Options) -> Task<Void, Error> {
        Task(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }

            try await self.cancel(forRestart: true).value
            await MainActor.run { self.acc.reset() }
            _ = self.start(options: options)
        }
    }

    public func stop() -> Task<Void, Error> {
        Task(priority: .userInitiated) { [weak self] in
            guard let self = self else { throw SwishError.jobNotStarted }
            guard let task = self.task else {
                throw SwishError.jobNotStarted
            }
            await MainActor.run {
                self.setState(.stopping)
                self.acc.stopAccumulating = true
            }
            task.cancel()
            try await task.value
            await MainActor.run { self.setState(.done) }
        }
    }

    public func cancel(forRestart: Bool = false) -> Task<Void, Error> {
        Task(priority: .userInitiated) { [weak self] in
            guard let self = self else { throw SwishError.jobNotStarted }
            guard let task = self.task else {
                throw SwishError.jobNotStarted
            }
            await MainActor.run {
                if forRestart {
                    self.setState(.restarting)
                } else {
                    self.setState(.cancelling)
                }
                self.acc.stopAccumulating = true
            }
            task.cancel()
            try await task.value
        }
    }
}
