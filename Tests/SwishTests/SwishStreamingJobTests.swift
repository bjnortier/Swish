//
//  Test.swift
//  Swish
//
//  Created by Ben Nortier on 2025/05/26.
//

import Testing
import Foundation
@testable import Swish

@MainActor
private final class ChunkedStreamingEngine: SwishStreamingEngine {
    var task: Task<Void, Error>?
    var paused: Bool = false

    let chunks: [[Float]]
    var chunkIndex: Int

    init(samples: [Float]) {
        self.chunks = toChunks(samples: samples, chunkSize: WhisperConstants.samplingFrequency * 1)
        self.chunkIndex = 0
    }

    func startStreaming(bufferActor: SwishBufferActor) {
        task = Task { [weak self] in
            guard let self = self else { return }

            while chunkIndex < chunks.count {
                while paused {
                    try await Task.sleep(for: .milliseconds(100))
                    await Task.yield()
                }
                if !Task.isCancelled {
                    await bufferActor.append(chunks[chunkIndex])
                    chunkIndex += 1
                    try await Task.sleep(for: .milliseconds(200))
                    await Task.yield()
                }
            }
        }
    }

    func pauseStreaming() {
        paused = true
    }

    func unpauseStreaming() {
        paused = false
    }

    func stopStreaming() {
        task?.cancel()
    }
}

struct SwishStreamingJobTests {

    let aragornSamples: [Float]!
    let modelPath: String

    init() async throws {
        aragornSamples = try readWAV(
            Bundle.module.url(forResource: "aragorn", withExtension: "wav")!
        ).toFloatArray()
        modelPath = Bundle.module.path(forResource: "ggml-tiny", ofType: "bin")!
    }

    @MainActor
    @Test func testStreamningAragorn() async throws {
        let job = SwishStreamingJob(
            streamingEngine: ChunkedStreamingEngine(samples: aragornSamples))
        let options = SwishJob.Options(
            model: WhisperModel.tiny,
            modelPath: modelPath)

        _ = job.start(options: options)

        try await Task.sleep(for: .seconds(5))
        try await job.stop().value


        #expect(job.acc.getTranscription().similarityPercentage(to: " I see in your eyes, the same fear that would take the half of me. The day may come, and the courage of men pray, and we will sink our friends and pray all [MUSIC] But it is not this game, and I will hold and shut the seal for me to get up to class and now, but it is not this bad. This day we fight, by all they can hold here. This could have, I've been in start, and I'm lost.") > 0.8)

    }

}
