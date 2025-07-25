//
//  SwiftJob.swift
//  Swish
//
//  Created by Ben Nortier on 2025/05/22.
//

import Combine
import SwiftUI

@MainActor
@Observable public class SwishJob: Identifiable {
    public enum State: String {
        case created
        case loadingModel
        case transcribing
        case paused
        case stopping
        case cancelling
        case cancelled
        case restarting
        case done
        case error

        public var isBusy: Bool {
            switch self {
            case .loadingModel, .transcribing, .stopping, .cancelling, .restarting:
                return true
            default:
                return false

            }

        }

    }

    private(set) var modelPath: String?
    private(set) var options: SwishTranscriber.Options?
    private(set) var transcriber: SwishTranscriber?
    public let transcription: SwishTranscription
    let abortController: SwishAbortController
    public private(set) var state: State
    public var error: Error?
    public var task: Task<Void, Error>?

    public init() {
        self.state = .created
        self.transcription = .init()
        self.abortController = .init()
        self.transcriber = nil
        self.error = nil
        self.modelPath = nil
        self.options = nil

    }

    func setState(_ state: State, error: Error? = nil) {
        precondition(
            state != .error || error != nil,
            "Error can only be set when state is .error and must not be nil")
        //        DispatchQueue.main.async {
        // Avoid unnecessary notifications
        if self.error == nil, error != nil {
            self.error = error
        } else if self.error != nil, error == nil {
            self.error = error
        }
        if self.state != state {
            self.state = state
        }
    }

    func createOrReuseTranscriber(modelPath newModelPath: String) async throws -> SwishTranscriber {
        // When restarting, create a new transcriber if the model is different
        if let existingTranscriber = transcriber,
            let oldModelPath = modelPath
        {
            if newModelPath != oldModelPath {
                return try await createTranscriber(modelPath: newModelPath)

            } else {
                return existingTranscriber
            }
        } else {
            return try await createTranscriber(modelPath: newModelPath)
        }
    }

    @MainActor
    private func createTranscriber(modelPath: String) async throws -> SwishTranscriber {
        setState(.loadingModel)
        let transcriber = SwishTranscriber(
            modelPath: modelPath
        )
        try await transcriber.loadModel()
        self.transcriber = transcriber
        self.modelPath = modelPath
        return transcriber
    }

    func destroyTranscriber() {
        transcriber = nil
    }
}
