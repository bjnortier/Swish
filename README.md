# Swish

## Introduction

Swish is a Swift/SwiftUI library for transcribing audio on iOS and macOS using [whisper.cpp](https://github.com/ggml-org/whisper.cpp). It can be used to transcribe audio files or transcribe audio from the microphone in real-time. 

Swish adds some functionality on top of whisper.cpp:

1. Adds thread-safe support for whisper.cpp.
2. Adds full Swift 6 strict concurrency conformance.
3. Adds Observability for rendering transcription results in real time.
4. Adds live transcription from the microphone from SwiftUI (including audio conversion to the required format).

## Requirements

Swish requires iOS 17.0+, iPadOS 17.0+, and macOS 14.0+.

To run the tests in this repo git-lfs is required to download the test WAV files and Whisper model.

## Installation

Add Swish to your project using Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/Swish.git", from: "1.0.0")
]
```

## Developer Documentation

### Core Architecture

Swish is built around several key components that work together to provide thread-safe audio transcription:

#### Main Components

- **`SwishTranscriber`** - Actor-based wrapper around whisper.cpp for thread-safe transcription
- **`SwishJob`** - Observable base class for managing transcription job state and lifecycle  
- **`SwishFileJob`** - Job for transcribing pre-recorded audio files
- **`SwishStreamingJob`** - Job for real-time streaming transcription from microphone
- **`SwishAccumulator`** - Thread-safe accumulator for transcription segments
- **`SwishAudioBuffer`** - Actor for managing audio sample buffers during streaming
- **`SwishStreamingEngine`** - Protocol for audio streaming engines (microphone, etc.)

### Basic Usage

#### Transcribing Audio Files

```swift
import Swish

// Create a job for file transcription
let samples: [Float] = // your audio samples at 16kHz
let job = SwishFileJob(samples: samples)

// Configure transcription options
let options = SwishJob.Options(
    model: .tiny,
    modelPath: "/path/to/model.bin",
    audioLanguage: "en",
    translateToEN: false
)

// Start transcription
let task = job.start(options: options)

// Observe results in real-time
Text(job.acc.getTranscription())
```

#### Real-time Microphone Transcription

```swift
import Swish

// Create streaming engine and job
let engine = SwishMicrophoneStreamingEngine()
let job = SwishStreamingJob(streamingEngine: engine)

// Configure options
let options = SwishJob.Options(
    model: .tiny,
    modelPath: "/path/to/model.bin"
)

// Start streaming transcription
let task = job.start(options: options)

// Display results
Text(job.acc.getTranscription())
```

### API Reference

#### SwishJob.Options

Configuration options for transcription jobs:

```swift
public struct Options {
    public let model: WhisperModel
    public let modelPath: String
    public let audioLanguage: String      // Default: "auto"
    public let translateToEN: Bool        // Default: false
    public let tokenTimestamps: Bool      // Default: false
    public let maxSegmentTokens: Int      // Default: 0
    public let beamSize: Int             // Default: 5 (0-8)
}
```

#### SwishJob State Management

Jobs have observable states that you can monitor:

```swift
public enum State {
    case created
    case preprocessing
    case loadingModel
    case transcribing
    case paused
    case stopping
    case cancelling
    case cancelled
    case restarting
    case done
    case error
}
```

Key job operations:

```swift
// Start transcription
func start(options: Options) -> Task<Void, Error>

// Stop gracefully (waits for current processing to finish)
func stop() -> Task<Void, Error>

// Cancel immediately
func cancel() -> Task<Void, Error>

// Restart with new options
func restart(options: Options) -> Task<Void, Error>
```

#### SwishStreamingJob Additional Operations

For streaming jobs, additional controls are available:

```swift
// Pause/resume streaming
func pause() -> Task<Void, Error>
func unpause() -> Task<Void, Error>

// Clear accumulated transcription
func clear() -> Task<Void, Error>
```

#### SwishAccumulator

Thread-safe accumulator for transcription results:

```swift
// Get all segments
public var segments: [SwishSegment] { get set }

// Get transcription as single string
public func getTranscription() -> String

// Reset accumulator
public func reset()

// Thread-safe append (used internally by callbacks)
public func appendSegments(_ newSegments: [SwishSegment])
```

#### SwishSegment

Represents a transcribed segment:

```swift
public struct SwishSegment {
    public let t0: Int        // Start time in milliseconds * 100
    public let t1: Int        // End time in milliseconds * 100  
    public let text: String   // Transcribed text
}
```

### Advanced Usage

#### Custom Streaming Engine

You can implement your own streaming engine by conforming to `SwishStreamingEngine`:

```swift
public protocol SwishStreamingEngine {
    func startStreaming(bufferActor: SwishAudioBuffer) throws
    func pauseStreaming() throws
    func unpauseStreaming() throws  
    func stopStreaming() throws
}
```

#### Audio Format Requirements

Swish expects audio data as `[Float]` samples at 16kHz sampling rate. For other formats, you'll need to convert them first.

#### Threading and Concurrency

- `SwishTranscriber` is an actor providing thread-safe access to whisper.cpp
- `SwishJob` subclasses are `@MainActor` classes for SwiftUI integration
- `SwishAccumulator` uses concurrent queues for thread-safe segment accumulation
- All async operations return `Task` objects for proper cancellation handling

### Error Handling

Swish defines comprehensive error types in `SwishError`:

```swift
public enum SwishError: Error {
    case couldNotInitializeContext(modelPath: String)
    case modelNotLoaded
    case emptyInputBuffer
    case invalidBeamSize(size: Int)
    case jobNotStarted
    case engineNotInitialized
    // ... and more
}
```

### Testing

Run tests with:

```bash
swift test
```

Note: Tests require git-lfs for downloading test audio files and Whisper models.

### Performance Considerations

- Model loading is done once per transcriber and can be reused across jobs
- Streaming jobs use overlapping audio frames to improve transcription quality
- The library automatically optimizes thread usage based on available CPU cores
- GPU acceleration is enabled by default on device (disabled in simulator)

## Whisper.cpp Version and Models

This library uses whisper.cpp v1.7.6. You'll need to provide your own Whisper model files in the GGML format.

## Formatting

This project uses swift-format to format the code. The configuration is in the `.swift-format` file.
