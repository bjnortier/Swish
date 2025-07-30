//
//  HTAbortController.swift
//  HTKit
//
//  Created by Ben Nortier on 2025/07/21.
//

import Foundation
import SwiftUI

// The Abort Controller is used to stop the whisper.cpp C++ process
public final class HTAbortController: @unchecked Sendable {
    // Private backing storage
    private var _stop_requested: Bool = false

    // Concurrent queue for thread-safe access
    private let queue = DispatchQueue(
        label: "com.bjnortier.HTKit.AbortQueue", attributes: .concurrent)

    public init() {
        self._stop_requested = false
    }

    // Thread-safe property access
    var stop_requested: Bool {
        get { queue.sync { _stop_requested } }
    }

    // Thread-safe stop
    public func stop() {
        queue.async(flags: .barrier) { self._stop_requested = true }
    }

    // Thread-safe reset
    public func reset() {
        queue.async(flags: .barrier) { self._stop_requested = false }
    }


}
