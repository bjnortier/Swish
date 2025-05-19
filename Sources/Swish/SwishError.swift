//
//  SwishError.swift
//  Swish
//
//  Created by Ben Nortier on 2025/01/10.
//

public enum SwishError: Error {
    case couldNotInitializeContext(modelPath: String)
    case audioFormatError
    case bufferCreationError
    case dataConversionError
    case invalidMemoryLayout
    case emptyInputBuffer
    case invalidBeamSize(size: Int)
    case modelNotLoaded
}
