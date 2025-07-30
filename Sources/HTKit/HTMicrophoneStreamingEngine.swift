//
//  HTMicrophoneStreamingEngine.swift
//  HTKit
//
//  Created by Ben Nortier on 2025/07/03.
//
import AVFoundation

public class HTMicrophoneStreamingEngine: HTStreamingEngine {

    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?

    public init() {
        // Do nothing, a public initializer is required
    }

    public func startStreaming(buffer: HTStreamingAudioBuffer) throws {
        do {
            #if os(iOS)
                try configureAudioSession()
            #endif

            // Start audio engine (isolated in its own actor)
            try setupAndStartEngine {
                samples in
                Task {
                    await buffer.append(samples)
                }
            }
        } catch {
            logger.error(
                "Failed to start recording: \(error.localizedDescription)"
            )
        }
    }

    public func pauseStreaming() throws {
        guard let audioEngine else {
            logger.error("Can't pause audio when engine is not initialized.")
            return
        }
        audioEngine.pause()
    }

    public func unpauseStreaming() throws {
        guard let audioEngine else {
            logger.error("Can't unpause audio when engine is not initialized.")
            return
        }
        try audioEngine.start()
    }

    public func stopStreaming() throws {
        guard let audioEngine else {
            logger.error("Can't stop audio when engine is not initialized.")
            return
        }

        // Remove tap first
        inputNode?.removeTap(onBus: 0)

        // Stop and reset engine
        audioEngine.stop()
        audioEngine.reset()

        // Clear references
        self.audioEngine = nil
        self.inputNode = nil

        // Deactivate audio session on iOS
        #if os(iOS)
            Task.detached {
                do {
                    try AVAudioSession.sharedInstance().setActive(false)
                } catch {
                    print("Failed to deactivate audio session: \(error)")
                }
            }
        #endif
    }

    #if os(iOS)
        private func configureAudioSession() throws {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record)
            try session.setActive(true)
        }
    #endif

    func setupAndStartEngine(
        onSamplesReceived: @escaping @Sendable ([Float]) -> Void
    ) throws {
        // Create audio engine
        let engine = AVAudioEngine()
        self.audioEngine = engine
        self.inputNode = engine.inputNode

        guard let inputNode = inputNode else {
            throw HTError.engineNotInitialized
        }

        let inputFormat = inputNode.inputFormat(forBus: 0)
        logger.info(
            "Input sample rate: \(inputFormat.sampleRate, privacy: .public)"
        )
        guard inputFormat.sampleRate > 0 else {
            throw HTError.zeroInputSampleRate
        }

        guard
            let outputAudioFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: Double(WhisperConstants.samplingFrequency),
                channels: 1,
                interleaved: false
            )
        else {
            throw HTError.nilOutputAudioFormat
        }

        let converter = AVAudioConverter(
            from: inputFormat,
            to: outputAudioFormat
        )

        // Remove any existing tap
        inputNode.removeTap(onBus: 0)

        // Install tap - the callback will be called on a real-time thread
        inputNode.installTap(
            onBus: 0,
            bufferSize: 1024,
            format: inputFormat
        ) { buffer, _ in
            guard let converter = converter else { return }
            let frameLength = Int(buffer.frameLength)
            guard frameLength > 0 else { return }

            // Process audio in the real-time thread directly
            if let samples = convert(
                inputBuffer: buffer,
                converter: converter,
                outputFormat: outputAudioFormat
            ) {
                Task.detached {
                    onSamplesReceived(samples)
                }
            }
        }

        // Prepare and start the engine
        engine.prepare()
        try engine.start()
    }

}

// Convert the input buffer to the desired Whisper output format,
// and convert to an [Float] array which can be processes by Whisper
func convert(
    inputBuffer: AVAudioPCMBuffer,
    converter: AVAudioConverter,
    outputFormat: AVAudioFormat
) -> [Float]? {
    let outputFrameCapacity = AVAudioFrameCount(
        round(
            Double(inputBuffer.frameLength)
                * (outputFormat.sampleRate / inputBuffer.format.sampleRate)
        )
    )

    guard
        let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: outputFrameCapacity
        )
    else { return nil }

    converter.convert(to: outputBuffer, error: nil) { _, status in
        status.pointee = .haveData
        return inputBuffer
    }

    if let channelData = outputBuffer.floatChannelData {
        let channelDataPointer = channelData.pointee
        let samples: [Float] = stride(
            from: 0,
            to: Int(outputBuffer.frameLength),
            by: outputBuffer.stride
        ).map { channelDataPointer[$0] }

        return samples
    } else {
        return nil
    }
}
