import Foundation
import Testing

@testable import HTKit

@Suite(.serialized)
struct HTTranscriberTests {

    let jfkSamples: [Float]!
    let aragornSamples: [Float]!
    let transcriber: HTTranscriber!

    init() async throws {
        jfkSamples = try readWAV(Bundle.module.url(forResource: "jfk", withExtension: "wav")!)
            .toFloatArray()
        aragornSamples = try readWAV(
            Bundle.module.url(forResource: "aragorn", withExtension: "wav")!
        ).toFloatArray()
        transcriber = HTTranscriber(
            modelPath: Bundle.module.path(forResource: "ggml-tiny", ofType: "bin")!)
        try await transcriber.loadModel()
    }

    @Test func testBasicTranscription() async throws {
        let transcription: HTTranscription = .init()
        let abortController = HTAbortController()
        let options = HTTranscriber.Options(
            beamSize: 0
        )
        try await transcriber.transcribe(
            samples: jfkSamples,
            transcription: transcription,
            abortController: abortController,
            options: options)
        let text = transcription.getText()
        let similarity = text.similarityPercentage(
            to:
                " And so my fellow Americans ask not what your country can do for you, ask what you can do for your country.",
        )
        #expect(similarity > 80)
    }

    @Test func testAragorn() async throws {
        let transcription: HTTranscription = .init()
        let abortController = HTAbortController()
        let options = HTTranscriber.Options(
            beamSize: 0
        )
        try await transcriber.transcribe(
            samples: aragornSamples,
            transcription: transcription,
            abortController: abortController,
            options: options)
        #expect(
            transcription.getText().similarityPercentage(
                to:
                    " [chatter] I see you right. The same fear that would take the half of me. The day may come, and the courage of men pray, and we will seek our friends and pray all bonds of fellowship, but it is not distinct. And our rules and shepherds see on the edge of the crossings now, but it is not distinct. This day may come, and we will seek our friends and pray all together. [chatter]"
            )
                > 50)
    }

    @Test func testAbort() async throws {
        let transcription: HTTranscription = .init()
        let abortController = HTAbortController()
        let options = HTTranscriber.Options(
            beamSize: 0
        )
        abortController.stop()
        try await transcriber.transcribe(
            samples: aragornSamples,
            transcription: transcription,
            abortController: abortController,
            options: options)

        #expect(transcription.segments.isEmpty)
    }

}
