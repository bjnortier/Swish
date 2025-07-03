//
//  Test.swift
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

    init() async throws {
        jfkSamples = try readWAV(Bundle.module.url(forResource: "jfk", withExtension: "wav")!)
            .toFloatArray()
    }

    @MainActor
    @Test func testFullJFK() async throws {
        let job = SwishFileJob(samples: jfkSamples)
        let options = SwishJob.Options(
            model: WhisperModel.tiny,
            modelPath: Bundle.module.path(forResource: "ggml-tiny", ofType: "bin")!)

        try await job.start(options: options).value
        try await job.task!.value
        try await Task.sleep(for: .seconds(0.2))  // State is set on main thread
        #expect(job.state == .done)

        #expect(
            job.acc.getTranscription().similarityPercentage(
                to:
                    " And so, my fellow Americans, ask not what your country can do for you, ask what you can do for your country."
            ) > 80)
    }

    // A job with no samples should throw
    @MainActor
    @Test func testFullNoSamples() async throws {
        let job = SwishFileJob(samples: [])
        let options = SwishJob.Options(
            model: WhisperModel.tiny,
            modelPath: Bundle.module.path(forResource: "ggml-tiny", ofType: "bin")!)

        await #expect(throws: SwishError.emptyInputBuffer) {
            try await job.start(options: options).value
        }
        #expect(job.state == .error)
    }

    // Job can run in parallel
    @MainActor
    @Test func testParallel() async throws {
        let jobA = SwishFileJob(samples: jfkSamples)
        let jobB = SwishFileJob(samples: jfkSamples)
        let options = SwishJob.Options(
            model: WhisperModel.tiny,
            modelPath: Bundle.module.path(forResource: "ggml-tiny", ofType: "bin")!)

        let jobATask = jobA.start(options: options)
        let jobBTask = jobB.start(options: options)
        try await jobATask.value
        try await jobBTask.value
        #expect(jobA.state == .done)
        #expect(jobB.state == .done)

        #expect(
            jobA.acc.getTranscription().isSimilar(
                to:
                    " And so, my fellow Americans, ask not what your country can do for you, ask what you can do for your country.",
                atLeast: 0.8))

        #expect(
            jobB.acc.getTranscription().isSimilar(
                to:
                    " And so, my fellow Americans, ask not what your country can do for you, ask what you can do for your country.",
                atLeast: 0.8))

    }

}
