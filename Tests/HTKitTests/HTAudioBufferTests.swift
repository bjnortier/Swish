//
//  HTStreamingAudioBufferTests.swift
//  HTKit
//
//  Created by Ben Nortier on 2025/05/26.
//

import Testing

@testable import HTKit

struct HTStreamingAudioBufferTests {
    @Test("get samples")
    func testGetSamples() async throws {
        let buffer = HTStreamingAudioBuffer(minSamplesSize: 2, frameSize: 3, overlapSize: 1)
        let (samples1, isFrame1) = await buffer.getNextSamples()
        #expect(samples1 == nil)
        #expect(!isFrame1)

        // Intermediate fetch
        await buffer.append([0, 1])
        let (samples2, isFrame2) = await buffer.getNextSamples()
        #expect(samples2 == [0, 1])
        #expect(!isFrame2)

        // Fetch again but the whole frame. There is no overlap as it is the first frame
        await buffer.append([2, 3, 4, 5])
        let (samples3, isFrame3) = await buffer.getNextSamples()
        #expect(samples3 == [0, 1, 2])
        #expect(isFrame3)

        // Next frame. Overlap one sample from previous frame
        let (samples4, isFrame4) = await buffer.getNextSamples()
        #expect(samples4 == [2, 3, 4, 5])
        #expect(isFrame4)

        // Processing index is now at end of buffer
        let (samples5, isFrame5) = await buffer.getNextSamples()
        #expect(samples5 == nil)
        #expect(!isFrame5)
    }
}
