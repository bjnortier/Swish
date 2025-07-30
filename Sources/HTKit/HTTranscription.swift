//
//  HTTranscription.swift
//  HTKit
//
//  Created by Ben Nortier on 2025/02/28.
//

import Foundation
import SwiftUI

// This file defines the HTTranscription class, which is responsible for accumulating
// segments of transcribed text in a thread-safe manner. It uses a concurrent queue to
// ensure that access to its properties is thread-safe, allowing for safe updates from
// multiple threads, such as during streaming transcription processes.
@Observable public final class HTTranscription: @unchecked Sendable {
    // Private backing storage
    private var _segments: [HTTranscriptionSegment] = []
    private var _highWaterIndex: Int = 0

    var refreshID = UUID()

    // Concurrent queue for thread-safe access
    private let queue = DispatchQueue(
        label: "com.bjnortier.HTKit.TranscriptionQueue", attributes: .concurrent)

    // Thread-safe property access
    public var segments: [HTTranscriptionSegment] {
        get { queue.sync { _segments } }
        set {
            queue.async(flags: .barrier) {
                self._segments = newValue
                self.refreshID = UUID()
            }
        }
    }



    // Get the accumulated transcrtiption as a single string
    public func getText() -> String {
        return queue.sync { _segments.map(\.text).joined() }
    }

    public func reset() {
        queue.async(flags: .barrier) {
            self._segments = []
            self._highWaterIndex = 0
        }
    }

    // Thread-safe append method for C++ callbacks
    public func appendSegments(_ newSegments: [HTTranscriptionSegment]) {
        queue.async(flags: .barrier) {
            self._segments.append(contentsOf: newSegments)
        }
    }

    public func appendAtHighWaterMark(_ newSegments: [HTTranscriptionSegment], updateMark: Bool = false) {

        queue.async(flags: .barrier) {
            let count = self._segments.count

            var lastT1 = 0
            let lastT1Index = self._highWaterIndex - 1
            if lastT1Index >= 0, lastT1Index < count {
                lastT1 = self._segments[lastT1Index].t1
            }
            let timeShiftedSegments =
                newSegments
                .map { segment in
                    HTTranscriptionSegment(
                        t0: segment.t0 + lastT1,
                        t1: segment.t1 + lastT1,
                        text: segment.text
                    )
                }

            self._segments.removeLast(count - self._highWaterIndex)
            self._segments.append(contentsOf: timeShiftedSegments)
            if updateMark {
                self._highWaterIndex = self._segments.count
            }
        }

    }

}
