//
//  SwishStreamingEngine.swift
//  Swish
//
//  Created by Ben Nortier on 2025/05/26.
//

public protocol SwishStreamingEngine {
    func startStreaming(bufferActor: SwishAudioBuffer) throws
    func pauseStreaming() throws
    func unpauseStreaming() throws
    func stopStreaming() throws
}
