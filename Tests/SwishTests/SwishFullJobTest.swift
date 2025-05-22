//
//  Test.swift
//  Swish
//
//  Created by Ben Nortier on 2025/05/22.
//

import Foundation
import Testing

@testable import Swish

struct SwishFullJobTests {

    let jfkSamples: [Float]!

    init() async throws {
        jfkSamples = try readWAV(Bundle.module.url(forResource: "jfk", withExtension: "wav")!)
            .toFloatArray()
    }

    @MainActor
    @Test func testFullJFK() async throws {
        let job = SwishFullJob(samples: jfkSamples)
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

}
