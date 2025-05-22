import Foundation
import Testing

@testable import Swish

@Suite(.serialized)
struct TranscriberTests {

    let jfkSamples: [Float]!
    let aragornSamples: [Float]!
    let transcriber: SwishTranscriber!
    let acc: SwishAccumulator!

    init() async throws {
        jfkSamples = try readWAV(Bundle.module.url(forResource: "jfk", withExtension: "wav")!)
            .toFloatArray()
        aragornSamples = try readWAV(
            Bundle.module.url(forResource: "aragorn", withExtension: "wav")!
        ).toFloatArray()
        transcriber = SwishTranscriber(
            modelPath: Bundle.module.path(forResource: "ggml-tiny", ofType: "bin")!)
        try await transcriber.loadModel()
        acc = SwishAccumulator()
    }

    @Test func testBasicTranscription() async throws {
        try await transcriber.transcribe(samples: jfkSamples, acc: acc, beamSize: 0)
        #expect(
            acc.getTranscription().similarityPercentage(
                to:
                    " And so my fellow Americans ask not what your country can do for you, ask what you can do for your country.",
                ) > 80)
    }

    @Test func testAragorn() async throws {
        try await transcriber.transcribe(samples: aragornSamples, acc: acc, beamSize: 0)
        print(acc.getTranscription())
        #expect(
            acc.getTranscription().similarityPercentage(
                to:
                    " [chatter] I see you right. The same fear that would take the half of me. The day may come, and the courage of men pray, and we will seek our friends and pray all bonds of fellowship, but it is not distinct. And our rules and shepherds see on the edge of the crossings now, but it is not distinct. This day may come, and we will seek our friends and pray all together. [chatter]")
                > 50)
    }

    @Test func testAbort() async throws {
        acc.stopAccumulating = true
        try await transcriber.transcribe(samples: aragornSamples, acc: acc)

        #expect(acc.segments.isEmpty)
    }
}
