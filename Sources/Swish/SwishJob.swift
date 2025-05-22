//
//  SwiftJob.swift
//  Swish
//
//  Created by Ben Nortier on 2025/05/22.
//

import Combine
import SwiftUI

@Observable public class SwishJob {
    public enum State: String {
        case created
        case preprocessing
        case loadingModel
        case busy
        case paused
        case stopping
        case cancelling
        case cancelled
        case restarting
        case done
        case error
    }

    public struct Options: Hashable, Equatable {
        public let model: WhisperModel
        public let modelPath: String

        // Transcriber options
        public let audioLanguage: String
        public let translateToEN: Bool
        public let tokenTimestamps: Bool
        public let maxSegmentTokens: Int
        public let beamSize: Int

        public init(
            model: WhisperModel,
            modelPath: String,
            audioLanguage: String = "auto",
            translateToEN: Bool = false,
            tokenTimestamps: Bool = false,
            maxSegmentTokens: Int = 0,
            beamSize: Int = 5
        ) {
            self.model = model
            self.modelPath = modelPath
            self.audioLanguage = audioLanguage
            self.translateToEN = translateToEN
            self.tokenTimestamps = tokenTimestamps
            self.maxSegmentTokens = maxSegmentTokens
            self.beamSize = beamSize
        }
    }

    private(set) var options: Options?
    private(set) var transcriber: SwishTranscriber?
    public let acc: SwishAccumulator
    public private(set) var state: State
    public var error: Error?
    public var task: Task<Void, Error>?

    public init(
        state: State,
        acc: SwishAccumulator
    ) {
        self.state = state
        self.acc = acc
        self.error = nil
        self.options = nil
        self.transcriber = nil
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
        //        }
    }



    // This function has potential side-effects:
    // setting state to .loadingModel
    // setting self.options and self.transcriber
    func createOrReuseTranscriber(options newOptions: Options) throws -> SwishTranscriber {
        // When restarting, create a new transcriber if the model is different
        if let existingTranscriber = transcriber,
            let oldOptions = options
        {
            if newOptions.modelPath != oldOptions.modelPath {
                return try createTranscriber(options: newOptions)
            } else {
                return existingTranscriber
            }
        } else {
            return try createTranscriber(options: newOptions)
        }
    }

    private func createTranscriber(options: Options) throws -> SwishTranscriber {
        setState(.loadingModel)
        let transcriber = SwishTranscriber(
            modelPath: options.modelPath
        )
        //        try transcriber.loadModel()
        self.transcriber = transcriber
        self.options = options
        return transcriber
    }

    func destroyTranscriber() {
        transcriber = nil
    }
}
