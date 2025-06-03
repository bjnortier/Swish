//
//  WMSegmentAccumulator.swift
//  WhisperMetal
//
//  Created by Ben Nortier on 2025/02/28.
//

import Foundation
import SwiftUI

// This file defines the SwishAccumulator class, which is responsible for accumulating
// segments of transcribed text in a thread-safe manner. It uses a concurrent queue to
// ensure that access to its properties is thread-safe, allowing for safe updates from
// multiple threads, such as during streaming transcription processes.
@Observable public final class SwishAccumulator: @unchecked Sendable {
    // Private backing storage
    private var _segments: [SwishSegment] = []
    private var _stopAccumulating: Bool = false
    private var _highWaterIndex: Int = 0

    var refreshID = UUID()

    // Concurrent queue for thread-safe access
    private let queue = DispatchQueue(
        label: "com.bjnortier.Swish.AccumulatorQueue", attributes: .concurrent)

    // Thread-safe property access
    public var segments: [SwishSegment] {
        get { queue.sync { _segments } }
        set {
            queue.async(flags: .barrier) {
                self._segments = newValue
                self.refreshID = UUID()
            }
        }
    }

    // Thread-safe property access
    public var stopAccumulating: Bool {
        get { queue.sync { _stopAccumulating } }
        set { queue.async(flags: .barrier) { self._stopAccumulating = newValue } }
    }

    public init(stopAccumulating: Bool = false) {
        self._stopAccumulating = stopAccumulating
    }

    // Get the accumulated transcrtiption as a single string
    public func getTranscription() -> String {
        return queue.sync { _segments.map(\.text).joined() }
    }

    public func reset() {
        queue.async(flags: .barrier) {
            self._segments = []
            self._stopAccumulating = false
            self._highWaterIndex = 0
        }
    }

    // Thread-safe append method for C++ callbacks
    public func appendSegments(_ newSegments: [SwishSegment]) {
        queue.async(flags: .barrier) {
            self._segments.append(contentsOf: newSegments)
        }
    }

    public func appendAtHighWaterMark(_ newSegments: [SwishSegment], updateMark: Bool = false) {

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
                    SwishSegment(
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
