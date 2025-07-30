//
//  HTFileJobTests.swift
//  HTKit
//
//  Created by Ben Nortier on 2025/05/22.
//

import Foundation
import Testing

@testable import HTKit

@Suite(.serialized)
struct HTFileJobTests {

    let jfkSamples: [Float]!
    let modelPath: String!

    init() async throws {
        jfkSamples = try readWAV(Bundle.module.url(forResource: "jfk", withExtension: "wav")!)
            .toFloatArray()
        modelPath = Bundle.module.path(forResource: "ggml-tiny", ofType: "bin")!
    }

    @MainActor
    @Test func testFullJFK() async throws {
        let job = HTFileJob(samples: jfkSamples)
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
        let job = HTFileJob(samples: [])

        await #expect(throws: HTError.emptyInputBuffer) {
            try await job.start(modelPath: modelPath).value
        }
        #expect(job.state == .error)
    }

    @MainActor
    @Test func testStop() async throws {
        let job = HTFileJob(samples:jfkSamples)

        _ = job.start(modelPath: modelPath)
        try await job.stop()

        #expect(job.state == .done)
    }

    @MainActor
    @Test func testRestart() async throws {
        let job = HTFileJob(samples:jfkSamples)

        _ = job.start(modelPath: modelPath)
        _ = try await job.restart(modelPath: modelPath)
        try await job.restart(modelPath: modelPath).value

        #expect(job.state == .done)
        #expect(
            job.transcription.getText().similarityPercentage(
                to:
                    " And so, my fellow Americans, ask not what your country can do for you, ask what you can do for your country."
            ) > 80)
    }

    // Job can run in parallel
    @MainActor
    @Test func testParallel() async throws {
        let jobA = HTFileJob(samples: jfkSamples)
        let jobB = HTFileJob(samples: jfkSamples)

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
