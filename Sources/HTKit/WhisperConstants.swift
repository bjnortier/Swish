//
//  WhisperConstants.swift
//  HTKit
//
//  Created by Ben Nortier on 2023/04/24.
//

public enum WhisperConstants {
    public static let frameDurationSeconds = 30
    public static let samplingFrequency = 16000
    public static let whisperFrameSize = frameDurationSeconds * samplingFrequency
    public static let fftSize = 400
    public static let numberOfMels = 80
    public static let fftStep = 160  // 10ms
    public static let melSpectrogramSize = whisperFrameSize / fftStep * numberOfMels
}
