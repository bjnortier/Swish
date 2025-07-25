//
//  SwishFullJobTests.swift
//  Swish
//
//  Created by Ben Nortier on 2025/05/22.
//

import Foundation
import Testing

@testable import Swish

@Suite(.serialized)
struct SwishFullJobTests {

    let jfkSamples: [Float]!
    let modelPath: String!

    init() async throws {
        jfkSamples = try readWAV(Bundle.module.url(forResource: "jfk", withExtension: "wav")!)
            .toFloatArray()
        modelPath = Bundle.module.path(forResource: "ggml-tiny", ofType: "bin")!
    }

    @MainActor
    @Test func testFullJFK() async throws {
        let job = SwishFileJob(samples: jfkSamples)
        let task = job.start(modelPath: modelPath)
        try await task.value

        #expect(job.state == .done)
        #expect(
            job.transcription.getText().similarityPercentage(
                to:
                    " And so, my fellow Americans, ask not what your country can do for you, ask what you can do for your country."
            ) > 80)
    }

    // A job with no samples should throw
    @MainActor
    @Test func testFullNoSamples() async throws {
        let job = SwishFileJob(samples: [])

        await #expect(throws: SwishError.emptyInputBuffer) {
            try await job.start(modelPath: modelPath).value
        }
        #expect(job.state == .error)
    }

    // Job can run in parallel
    @MainActor
    @Test func testParallel() async throws {
        let jobA = SwishFileJob(samples: jfkSamples)
        let jobB = SwishFileJob(samples: jfkSamples)

        let jobATask = jobA.start(modelPath: modelPath)
        let jobBTask = jobB.start(modelPath: modelPath)
        try await jobATask.value
        try await jobBTask.value
        #expect(jobA.state == .done)
        #expect(jobB.state == .done)

        #expect(
            jobA.transcription.getText().isSimilar(
                to:
                    " And so, my fellow Americans, ask not what your country can do for you, ask what you can do for your country.",
                atLeast: 0.8))

        #expect(
            jobB.transcription.getText().isSimilar(
                to:
                    " And so, my fellow Americans, ask not what your country can do for you, ask what you can do for your country.",
                atLeast: 0.8))

    }

}
