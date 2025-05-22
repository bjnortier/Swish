//
//  SwishError.swift
//  Swish
//
//  Created by Ben Nortier on 2025/01/10.
//

import Foundation

public enum SwishError: Error, Equatable, Hashable {
    case couldNotInitializeContext(modelPath: String)
    case audioFormatError
    case bufferCreationError
    case dataConversionError
    case invalidMemoryLayout
    case emptyInputBuffer
    case invalidBeamSize(size: Int)
    case modelNotLoaded
    case jobNotStarted
    case transcriptionFailed
}

extension SwishError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidMemoryLayout:
            return "Invalid memoty layout"
        case .couldNotInitializeContext(let modelPath):
            return "Could not initialize Whisper.cpp context with model path: \(modelPath)"
        case .audioFormatError:
            return "Audio format error"
        case .bufferCreationError:
            return "Buffer creation error"
        case .dataConversionError:
            return "Data conversion error"
        case .jobNotStarted:
            return "WhisperJob has not been started"
        case .emptyInputBuffer:
            return "Empty input buffer"
        case .invalidBeamSize(size: let size):
            return "Invalid beam size: \(size)"
        case .modelNotLoaded:
            return "Whisper model not loaded"
        case .transcriptionFailed:
            return "Transcription failed"
        }
    }
}
