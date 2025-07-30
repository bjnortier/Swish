//
//  HTStreamingEngine.swift
//  HTKit
//
//  Created by Ben Nortier on 2025/05/26.
//

public protocol HTStreamingEngine {
    func startStreaming(buffer: HTStreamingAudioBuffer) throws
    func pauseStreaming() throws
    func unpauseStreaming() throws
    func stopStreaming() throws
}
