import Foundation
import os
import whisper

// Wrapper for unchecked Sendable so that we can use it in an actor.
// Necessary for C/Swift interop.
final class ContextWrapper: @unchecked Sendable {
    let pointer: OpaquePointer

    init(_ pointer: OpaquePointer) {
        self.pointer = pointer
    }
}

// Received a new segment from whisper
private func newSegmentCallback(
    whisperContext: OpaquePointer?, whisperState: OpaquePointer?, nNew: Int32,
    userData: UnsafeMutableRawPointer?
) {
    let nSegments = whisper_full_n_segments(whisperContext)
    var segments: [SwishSegment] = []
    for segmentIndex: Int32 in nSegments - nNew..<nSegments {
        // Whisper.cpp times are in centiseconds, convert to milliseconds
        let segment = SwishSegment(
            t0: Int(whisper_full_get_segment_t0(whisperContext, segmentIndex)) * 10,
            t1: Int(whisper_full_get_segment_t1(whisperContext, segmentIndex)) * 10,
            text: String(cString: whisper_full_get_segment_text(whisperContext, segmentIndex))
        )
        segments.append(segment)
        logger.info("segment: \(String(describing: segment), privacy: .public)")
    }

    let acc = Unmanaged<SwishAccumulator>.fromOpaque(userData!).takeUnretainedValue()
    acc.segments.append(contentsOf: segments)
}

// Check if we should stop accumulating segments
private func abortCallback(userData: UnsafeMutableRawPointer?) -> Bool {
    let acc = Unmanaged<SwishAccumulator>.fromOpaque(userData!).takeUnretainedValue()
    return acc.stopAccumulating
}

public actor SwishTranscriber {
    private var contextWrapper: ContextWrapper?
    private let modelPath: String

    public init(modelPath: String) {
        self.modelPath = modelPath
    }

    deinit {
        if let contextWrapper {
            whisper_free(contextWrapper.pointer)
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
            throw SwishError.couldNotInitializeContext(modelPath: modelPath)
        }
        contextWrapper = ContextWrapper(context)
    }

    public func transcribe(
        samples: [Float],
        acc: SwishAccumulator,
        audioLanguage: String = "auto",
        translateToEN: Bool = false,
        tokenTimestamps: Bool = false,
        maxSegmentTokens: Int = 0,
        beamSize: Int = 5
    ) throws {
        guard let contextWrapper else {
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

        audioLanguage.withCString { en in
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

            let unsafeUserData = UnsafeMutableRawPointer(Unmanaged.passUnretained(acc).toOpaque())
            params.new_segment_callback = newSegmentCallback
            params.new_segment_callback_user_data = unsafeUserData
            params.abort_callback = abortCallback
            params.abort_callback_user_data = unsafeUserData
            whisper_reset_timings(contextWrapper.pointer)

            samples.withUnsafeBufferPointer { samples in
                if whisper_full(
                    contextWrapper.pointer, params, samples.baseAddress, Int32(samples.count))
                    != 0
                {
                    logger.error("Failed to run the model")
                } else {
                    whisper_print_timings(contextWrapper.pointer)
                }
            }
        }
    }

}

private func cpuCount() -> Int {
    ProcessInfo.processInfo.processorCount
}
