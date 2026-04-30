import Foundation
@preconcurrency import AVFoundation
import AppKit

enum MicAudioConstants {
    static let sampleRate: Double = 24000
    static let captureBufferSize: AVAudioFrameCount = 1024
    static let channels: AVAudioChannelCount = 1
    static let noiseGateThreshold: Float = 0.01
    static let noiseGateThresholdWithoutAEC: Float = 0.02
    static let noiseGateHoldTime: TimeInterval = 0.25
    static let noiseGateHoldTimeWithoutAEC: TimeInterval = 0.35
}

enum MicrophonePermissionState: String {
    case notDetermined, granted, denied, restricted

    var isDenied: Bool { self == .denied || self == .restricted }

    static func from(_ status: AVAuthorizationStatus) -> MicrophonePermissionState {
        switch status {
        case .notDetermined: return .notDetermined
        case .authorized: return .granted
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .denied
        }
    }
}

/// Mic capture at 24 kHz PCM mono with hardware AEC (VoiceProcessingIO) when available.
/// AEC is critical for meetings: system audio playing through speakers bleeds into the mic
/// and would otherwise be transcribed twice (once from system capture, once from mic).
final class MicCapture: ObservableObject {
    @MainActor @Published private(set) var isStreaming = false
    @MainActor @Published private(set) var isHardwareAECActive = false
    @MainActor @Published private(set) var permissionState: MicrophonePermissionState = .notDetermined

    /// Set before `start()`. Called from a non-main background queue per chunk.
    var onPCM16: (@Sendable (Data) -> Void)?
    /// Set before `start()`. Called from a non-main background queue with raw float samples.
    var onFloat32: (@Sendable (UnsafePointer<Float>, Int) -> Void)?

    private var engine: AVAudioEngine?
    private var tapNode: AVAudioNode?
    private let audioQueue = DispatchQueue(label: "co.blode.convene.mic")

    init() {
        Task { @MainActor in self.refreshPermission() }
    }

    @MainActor
    func refreshPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        permissionState = .from(status)
    }

    @MainActor
    func requestPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            permissionState = .granted
            return true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            refreshPermission()
            return granted
        default:
            permissionState = .from(status)
            return false
        }
    }

    @MainActor
    func start() throws {
        guard !isStreaming else { return }
        guard permissionState == .granted else {
            throw NSError(domain: "co.blode.convene.mic", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Microphone permission denied"])
        }

        let engine = AVAudioEngine()
        let input = engine.inputNode

        var voiceProcessingEnabled = true
        do {
            try input.setVoiceProcessingEnabled(true)
            logInfo("MicCapture: VoiceProcessingIO enabled (hardware AEC)")
        } catch {
            logInfo("MicCapture: VoiceProcessingIO unavailable, falling back to standard input")
            voiceProcessingEnabled = false
        }

        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.channelCount > 0, inputFormat.sampleRate > 0 else {
            throw NSError(domain: "co.blode.convene.mic", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid input format"])
        }

        let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: MicAudioConstants.sampleRate,
            channels: MicAudioConstants.channels,
            interleaved: false
        )!

        let captureFormat = inputFormat
        engine.prepare()

        // Per-stream state owned by the audio queue.
        let processor = MicAudioProcessor(
            captureFormat: captureFormat,
            targetFormat: targetFormat,
            hwAEC: voiceProcessingEnabled
        )
        let onPCM16 = self.onPCM16
        let onFloat32 = self.onFloat32
        let queue = audioQueue

        input.installTap(onBus: 0, bufferSize: MicAudioConstants.captureBufferSize, format: captureFormat) { buffer, _ in
            queue.async {
                processor.process(buffer: buffer, onFloat32: onFloat32, onPCM16: onPCM16)
            }
        }

        try engine.start()
        self.engine = engine
        self.tapNode = input
        self.isStreaming = true
        self.isHardwareAECActive = voiceProcessingEnabled
        logInfo("MicCapture: started (hwAEC=\(voiceProcessingEnabled))")
    }

    @MainActor
    func stop() {
        guard isStreaming else { return }
        engine?.stop()
        tapNode?.removeTap(onBus: 0)
        tapNode = nil
        engine = nil
        isStreaming = false
        isHardwareAECActive = false
        logInfo("MicCapture: stopped")
    }

    func flushPendingAudio() {
        audioQueue.sync {}
    }
}

/// Owns per-stream audio processing state (converter, noise-gate timestamp). Confined to
/// the audio dispatch queue — never accessed from elsewhere.
private final class MicAudioProcessor: @unchecked Sendable {
    private let captureFormat: AVAudioFormat
    private let targetFormat: AVAudioFormat
    private let hwAEC: Bool
    private var converter: AVAudioConverter?
    private var lastAboveThresholdTime: Date = .distantPast

    init(captureFormat: AVAudioFormat, targetFormat: AVAudioFormat, hwAEC: Bool) {
        self.captureFormat = captureFormat
        self.targetFormat = targetFormat
        self.hwAEC = hwAEC
        if captureFormat != targetFormat {
            self.converter = AVAudioConverter(from: captureFormat, to: targetFormat)
        }
    }

    func process(
        buffer: AVAudioPCMBuffer,
        onFloat32: (@Sendable (UnsafePointer<Float>, Int) -> Void)?,
        onPCM16: (@Sendable (Data) -> Void)?
    ) {
        guard let final = convert(buffer: buffer), let floatData = final.floatChannelData else { return }
        let frameCount = Int(final.frameLength)
        guard frameCount > 0 else { return }

        let threshold = hwAEC ? MicAudioConstants.noiseGateThreshold : MicAudioConstants.noiseGateThresholdWithoutAEC
        let holdTime = hwAEC ? MicAudioConstants.noiseGateHoldTime : MicAudioConstants.noiseGateHoldTimeWithoutAEC
        let now = Date()
        let rms = rmsLevel(floatData[0], frameCount: frameCount)

        if rms >= threshold {
            lastAboveThresholdTime = now
        } else if now.timeIntervalSince(lastAboveThresholdTime) >= holdTime {
            for i in 0..<frameCount { floatData[0][i] = 0 }
        }

        onFloat32?(floatData[0], frameCount)
        if let pcm16 = pcm16(from: floatData[0], frameCount: frameCount) {
            onPCM16?(pcm16)
        }
    }

    private func convert(buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        if captureFormat == targetFormat { return buffer }
        guard let converter else { return buffer }

        let frameCount = AVAudioFrameCount(Float(buffer.frameLength) * Float(targetFormat.sampleRate) / Float(captureFormat.sampleRate))
        guard let out = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCount) else { return nil }
        out.frameLength = frameCount

        var error: NSError?
        var consumed = false
        converter.convert(to: out, error: &error) { _, status in
            if consumed { status.pointee = .noDataNow; return nil }
            consumed = true
            status.pointee = .haveData
            return buffer
        }
        if let error { logError("MicCapture: conversion error: \(error)"); return nil }
        return out
    }

    private func rmsLevel(_ samples: UnsafePointer<Float>, frameCount: Int) -> Float {
        var sum: Float = 0
        for i in 0..<frameCount { sum += samples[i] * samples[i] }
        return (sum / Float(frameCount)).squareRoot()
    }

    private func pcm16(from samples: UnsafePointer<Float>, frameCount: Int) -> Data? {
        var data = Data(count: frameCount * 2)
        data.withUnsafeMutableBytes { raw in
            let int16 = raw.bindMemory(to: Int16.self)
            for i in 0..<frameCount {
                let scaled = Int32(samples[i] * 32767.0)
                int16[i] = Int16(max(-32768, min(32767, scaled))).littleEndian
            }
        }
        return data
    }
}
