//
//  SwishBufferActor.swift
//  Swish
//
//  Created by Ben Nortier on 2025/05/26.
//



// The BufferActor manages receiving samples from the source (e.g. a microphone)
// and exposing those samples to the client for transcription. It is a Swift actor
// because it will be accessed from multiple treads (the source and sink).
//
// There is a minimum sample size, if there are not enough samples yet they will not
// be returned.
// There is a frame size, which is the number of samples where a frame is finalized
// and the client moves on to the next frame.
// The is an overlap size, which is the number of samples from the previous frame
// that will be returned to alleviate issues with dropped words. This is a value
// determined by empirical experimentation.
public actor SwishBufferActor {
    private var buffer: [Float]
    private var minSamplesSize: Int
    private var frameSize: Int
    private var overlapSize: Int
    private var frameFromIndex: Int
    private var lastToIndex: Int?

    public init(minSamplesSize: Int, frameSize: Int, overlapSize: Int) {
        precondition(minSamplesSize < frameSize)
        buffer = []
        self.minSamplesSize = minSamplesSize
        self.frameSize = frameSize
        self.overlapSize = overlapSize
        frameFromIndex = 0
        lastToIndex = nil
    }

    public func append(_ samples: [Float]) {
        buffer.append(contentsOf: samples)
    }

    public func getNextSamples() -> ([Float]?, Bool) {
        if buffer.count == 0 {
            return (samples: nil, isFrame: false)
        }
        // No samples added after the processing checkpoint yet.
        if frameFromIndex == buffer.count {
            return (samples: nil, isFrame: false)
        }

        // Determine the range up to a max of "frameSize" samples
        var from = frameFromIndex
        let to = min(frameFromIndex + frameSize, buffer.count)

        // Enough samples for a frame?
        let isFrame = (to - from) == frameSize

        // Add overlap after determine is it's a frame otherwise
        // isFrame calculation becomes complicated to compensate
        // for overlap. Don't go negative.
        from = max(frameFromIndex - overlapSize, 0)

        // Return a minimun number of samples
        if (to - from) < minSamplesSize {
            return (samples: nil, isFrame: false)
        }

        // Already been transcribed
        if let lastToIndex {
            if lastToIndex == to {
                return (samples: nil, isFrame: false)
            }
        }

        let samples = Array(buffer[from ..< to])
        lastToIndex = to
        if isFrame {
            frameFromIndex = to
        }

        return (samples: samples, isFrame: isFrame)
    }

    @available(*, deprecated, message: "Is now reset()")
    public func clear() {
        buffer = []
        frameFromIndex = 0
        lastToIndex = nil
    }

    public func reset(clearBuffer: Bool) {
        if clearBuffer {
            buffer = []
        }
        frameFromIndex = 0
        lastToIndex = nil
    }
}
