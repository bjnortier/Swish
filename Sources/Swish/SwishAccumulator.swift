//
//  WMSegmentAccumulator.swift
//  WhisperMetal
//
//  Created by Ben Nortier on 2025/02/28.
//

import Foundation
import SwiftUI

@Observable public final class SwishAccumulator: @unchecked Sendable {
    public var segments: [SwishSegment] = []
    public var stopAccumulating: Bool
    private var highWaterIndex: Int = 0
    private let queue = DispatchQueue(
        label: "com.bjnortier.Swish.AccumulatorQueue", attributes: .concurrent)

    public init(stopAccumulating: Bool = false) {
        self.segments = []
        self.stopAccumulating = false
    }

    public func getTranscription() -> String {
        return segments.map(\.text).joined()
    }

    public func reset() {
        self.segments = []
        self.stopAccumulating = false
    }

    // Append the new segments at the mark and update the mark if specified.
    // Used during dictation when a frame is in a transient transcription state - i.e.
    // new samples for the frame are still being received to the frame will be re-transcribed.
    // The new segments are also time-shifted so they appear after the completed frames in the
    // timeline.
    public func appendAtHighWaterMark(_ newSegments: [SwishSegment], updateMark: Bool = false) {

        let count = self._segments.count

        var lastT1 = 0
        let lastT1Index = highWaterIndex - 1
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

        self.segments.removeLast(count - highWaterIndex)
        self.segments.append(contentsOf: timeShiftedSegments)
        if updateMark {
            self.highWaterIndex = self.segments.count
        }

    }
}
