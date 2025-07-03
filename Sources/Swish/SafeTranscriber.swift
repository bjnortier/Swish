//
//  SafeTranscriber.swift
//  Swish
//
//  Created by Ben Nortier on 2025/06/02.
//

import Foundation
import Observation
import whisper

@Observable
public class SafeTranscriber {

    public var segments: [SwishSegment] = []
    public var stop: Bool = false

    private let modelPath: String
    private var whisperContext: OpaquePointer? = nil

    public init(modelPath: String) {
        self.modelPath = modelPath
    }

    public func transcribe(
        samples: [Float],
        audioLanguage: String = "auto",
        translateToEN: Bool = false,
        tokenTimestamps: Bool = false,
        maxSegmentTokens: Int = 0,
        beamSize: Int = 5
    ) throws {
        guard let whisperContext else {
            throw SwishError.modelNotLoaded
        }
        guard samples.count > 0 else {
            throw SwishError.emptyInputBuffer
        }
        guard beamSize >= 0, beamSize <= 8 else {
            throw SwishError.invalidBeamSize(size: beamSize)
        }

        // Leave 2 processors free (i.e. the high-efficiency cores).
        let maxThreads = max(1, min(8, cpuCount() - 2))

        // Set up sampling parameters
        var params =
            beamSize == 0
            ? whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
            : whisper_full_default_params(WHISPER_SAMPLING_BEAM_SEARCH)
        if beamSize > 0 {
            params.beam_search.beam_size = Int32(beamSize)
        }

        try audioLanguage.withCString { en in
            // Parameters like call
            params.print_realtime = true
            params.print_progress = false
            params.print_timestamps = false
            params.print_special = false
            params.translate = translateToEN
            params.n_threads = Int32(maxThreads)
            params.offset_ms = 0
            params.no_context = true
            params.single_segment = false
            params.token_timestamps = tokenTimestamps
            params.max_len = Int32(maxSegmentTokens)
            params.language = en

            let dataContext = Unmanaged.passRetained(self).toOpaque()
            let unsafeUserData = UnsafeMutableRawPointer(dataContext)

            params.new_segment_callback = { whisperContext, whisperState, nNew, userData in

                let nSegments = whisper_full_n_segments(whisperContext)
                var segments: [SwishSegment] = []
                for segmentIndex: Int32 in nSegments - nNew..<nSegments {
                    let segment = SwishSegment(
                        t0: Int(whisper_full_get_segment_t0(whisperContext, segmentIndex)) * 10,
                        t1: Int(whisper_full_get_segment_t1(whisperContext, segmentIndex)) * 10,
                        text: String(
                            cString: whisper_full_get_segment_text(whisperContext, segmentIndex))
                    )
                    segments.append(segment)
                    logger.info("segment: \(String(describing: segment), privacy: .public)")
                }

                let transcriber = Unmanaged<SafeTranscriber>.fromOpaque(userData!)
                    .takeUnretainedValue()
                transcriber.segments.append(contentsOf: segments)
            }
            params.new_segment_callback_user_data = unsafeUserData

            params.abort_callback = { userData in
                let transcriber = Unmanaged<SafeTranscriber>.fromOpaque(userData!)
                    .takeUnretainedValue()
                return transcriber.stop
            }
            params.abort_callback_user_data = unsafeUserData

            whisper_reset_timings(self.whisperContext)

            try samples.withUnsafeBufferPointer { samples in
                let result = whisper_full(
                    whisperContext, params, samples.baseAddress, Int32(samples.count))

                // Whisper will return 0 on success, non-zero on failure or when stopped explicitly.
                if result != 0, !self.stop {
                    logger.error("Failed to run the model")
                    throw SwishError.transcriptionFailed
                } else {
                    whisper_print_timings(whisperContext)
                }
            }
        }
    }

    public func loadModel() throws {
        var params = whisper_context_default_params()
        #if targetEnvironment(simulator)
            params.use_gpu = false
            print("Running on the simulator, using CPU")
        #else
            params.flash_attn = true  // Enabled by default for Metal
        #endif
        let context = whisper_init_from_file_with_params(modelPath, params)
        guard let context else {
            throw SwishError.couldNotInitializeContext(modelPath: self.modelPath)
        }
        self.whisperContext = context
    }

    private func newSegmentCallback(
        whisperContext: OpaquePointer?, whisperState: OpaquePointer?, nNew: Int32,
        userData: UnsafeMutableRawPointer?
    ) {
        let nSegments = whisper_full_n_segments(whisperContext)
        var segments: [SwishSegment] = []
        for segmentIndex: Int32 in nSegments - nNew..<nSegments {
            let segment = SwishSegment(
                t0: Int(whisper_full_get_segment_t0(whisperContext, segmentIndex)) * 10,
                t1: Int(whisper_full_get_segment_t1(whisperContext, segmentIndex)) * 10,
                text: String(cString: whisper_full_get_segment_text(whisperContext, segmentIndex))
            )
            segments.append(segment)
            logger.info("segment: \(String(describing: segment), privacy: .public)")
        }

        let acc = Unmanaged<SwishAccumulator>.fromOpaque(userData!).takeUnretainedValue()
        acc.appendSegments(segments)  // Use thread-safe method
    }

}

private func cpuCount() -> Int {
    ProcessInfo.processInfo.processorCount
}
