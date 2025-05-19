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

    public init() {
        self.segments = []
        self.stopAccumulating = false
    }

    public func getTranscription() -> String {
        return segments.map(\.text).joined()
    }
}
