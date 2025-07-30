//
//  HTFileJob.swift
//  HTKit
//
//  Created by Ben Nortier on 2025/05/22.
//

import Foundation
import os

public class HTFileJob: HTJob {

    private var samples: [Float]

    public init(samples: [Float]) {
        self.samples = samples
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

        return self.start(modelPath: modelPath, options: options)
    }

    private func transcribe(modelPath: String, options: HTTranscriber.Options) async throws {
        let transcriber = try await self.createOrReuseTranscriber(modelPath: modelPath)
        self.setState(.transcribing)
        _ = try await transcriber.transcribe(
            samples: samples,
            transcription: self.transcription,
            abortController: self.abortController,
            options: options,
        )
    }

}
