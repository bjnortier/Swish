//
//  SwishFullJob.swift
//  Swish
//
//  Created by Ben Nortier on 2025/05/22.
//

import Foundation
import os

public class SwishFileJob: SwishJob {

    private var samples: [Float]

    public init(samples: [Float]) {
        self.samples = samples
        super.init()
    }

    public func start(modelPath: String, options: SwishTranscriber.Options = .init()) -> Task<
        Void, Error
    > {
        let task = Task(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }

            do {
                let transcriber = try await self.createOrReuseTranscriber(modelPath: modelPath)

                self.setState(.transcribing)
                _ = try await transcriber.transcribe(
                    samples: samples,
                    transcription: self.transcription,
                    abortController: self.abortController,
                    options: options,

                )
                self.setState(.done)
        } catch {
                self.setState(.error, error: error)
                throw error
            }
        }
        self.task = task
        return task
    }

    public func restart(modelPath: String, options: SwishTranscriber.Options) -> Task<Void, Error> {
        Task(priority: .userInitiated) { @MainActor [weak self] in
            guard let self = self else { return }
            guard let task = self.task else {
                throw SwishError.jobNotStarted
            }

            self.setState(.restarting)
            self.abortController.stop()
            task.cancel()
            try await task.value

            self.transcription.reset()
            self.abortController.reset()
            _ = self.start(modelPath: modelPath, options: options)
        }
    }

    public func cancel() -> Task<Void, Error> {
        Task(priority: .userInitiated) { @MainActor [weak self] in
            guard let self = self else { return }
            guard let task = self.task else {
                throw SwishError.jobNotStarted
            }

            self.setState(.cancelling)
            self.abortController.stop()
            task.cancel()
            try await task.value
            self.setState(.cancelled)
            self.destroyTranscriber()
        }
    }

    public func stop() -> Task<Void, Error> {
        Task(priority: .userInitiated) { @MainActor [weak self] in
            guard let self = self else { return }
            guard let task = self.task else {
                throw SwishError.jobNotStarted
            }
            self.setState(.stopping)

            // Stop the transcriber via the callback and wait for it to
            // finish
            self.abortController.reset()
            task.cancel()
            try await task.value

            self.setState(.done)
        }

    }
}
