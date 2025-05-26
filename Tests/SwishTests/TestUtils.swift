//
//  TestUtils.swift
//  WhisperMetal
//
//  Created by Ben Nortier on 2025/01/10.
//

import AVFoundation

@testable import Swish

extension Data {
    func toFloatArray() throws -> [Float] {
        guard self.count % MemoryLayout<Float>.stride == 0 else {
            throw SwishError.invalidMemoryLayout
        }
        return self.withUnsafeBytes { .init($0.bindMemory(to: Float.self)) }
    }
}

public func readWAV(_ wavURL: URL) throws -> Data {
    let file = try AVAudioFile(forReading: wavURL)
    guard
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: file.fileFormat.sampleRate,
            channels: 1,
            interleaved: false)
    else {
        throw SwishError.audioFormatError
    }
    guard
        let buf = AVAudioPCMBuffer(
            pcmFormat: format, frameCapacity: AVAudioFrameCount(Int(file.length)))
    else {
        throw SwishError.bufferCreationError
    }
    try file.read(into: buf)

    guard let floatChannelData = buf.floatChannelData else {
        throw SwishError.dataConversionError
    }
    return Data(bytes: floatChannelData[0], count: Int(buf.frameLength * 4))
}

extension String {
    /// Calculates the Levenshtein distance between two strings
    func levenshtein(to target: String) -> Int {
        // Handle edge cases
        if self == target { return 0 }
        if isEmpty { return target.count }
        if target.isEmpty { return count }

        // Convert strings to arrays for faster indexing
        let source = Array(self)
        let target = Array(target)

        // Create a distance matrix
        var distance = Array(
            repeating: Array(repeating: 0, count: target.count + 1),
            count: source.count + 1
        )

        // Initialize first row and column
        for i in 0...source.count {
            distance[i][0] = i
        }

        for j in 0...target.count {
            distance[0][j] = j
        }

        // Calculate distance
        for i in 1...source.count {
            for j in 1...target.count {
                if source[i - 1] == target[j - 1] {
                    // No change needed
                    distance[i][j] = distance[i - 1][j - 1]
                } else {
                    // Take minimum of three operations: deletion, insertion, substitution
                    distance[i][j] = Swift.min(
                        distance[i - 1][j] + 1,  // deletion
                        distance[i][j - 1] + 1,  // insertion
                        distance[i - 1][j - 1] + 1  // substitution
                    )
                }
            }
        }

        return distance[source.count][target.count]
    }

    /// Calculates similarity percentage compared to another string
    func similarityPercentage(to target: String) -> Double {
        let distance = levenshtein(to: target)
        let maxLength = max(self.count, target.count)

        // If both strings are empty, they're 100% similar
        if maxLength == 0 { return 100.0 }

        // Calculate similarity percentage based on distance
        return (1.0 - Double(distance) / Double(maxLength)) * 100.0
    }

    /// Asserts that the string is at least the specified percentage similar to the target string
    func isSimilar(to target: String, atLeast percentage: Double)
        -> Bool
    {
        let actualPercentage = similarityPercentage(to: target)
        return actualPercentage >= percentage
    }
}


func toChunks(samples: [Float], chunkSize: Int) -> [[Float]] {
    var chunks: [[Float]] = []
    let numberOfChunks = Int(ceil(Float(samples.count) / Float(chunkSize)))
    var remainingSamples = samples
    for _ in 0 ..< numberOfChunks {
        let toTake = min(chunkSize, remainingSamples.count)
        chunks.append(Array(remainingSamples[0 ..< toTake]))
        remainingSamples.removeFirst(toTake)
    }
    return chunks
}
