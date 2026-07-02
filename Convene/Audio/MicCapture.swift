import Foundation
@preconcurrency import AVFoundation
import AppKit

enum MicAudioConstants {
    static let sampleRate = Double(TranscriptionAudio.sampleRate)
    static let captureBufferSize: AVAudioFrameCount = 1024
    static let noiseGateThreshold: Float = 0.006
    static let noiseGateHoldTime: TimeInterval = 0.35
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

/// Mic capture at 16 kHz PCM mono. Hardware AEC (VoiceProcessingIO) is deliberately off —
/// see `start()` for why — so a local noise gate compensates instead.
final class MicCapture: ObservableObject {
    @MainActor @Published private(set) var isStreaming = false
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

        // We deliberately do NOT enable VoiceProcessingIO. It provides hardware AEC, but as a
        // side effect macOS ducks all other system audio while it's active, making whatever is
        // playing through the speakers go quiet during a recording. Like Granola, we capture the
        // mic and system audio as two separate raw streams and rely on diarization instead, so
        // the speaker stays at full volume. The noise-gate threshold compensates.
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.channelCount > 0, inputFormat.sampleRate > 0 else {
            throw NSError(domain: "co.blode.convene.mic", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid input format"])
        }

        let captureFormat: AVAudioFormat
        if inputFormat.channelCount == TranscriptionAudio.channels {
            captureFormat = inputFormat
        } else {
            captureFormat = AVAudioFormat(
                standardFormatWithSampleRate: inputFormat.sampleRate,
                channels: TranscriptionAudio.channels
            ) ?? TranscriptionAudio.targetFormat
            logInfo("MicCapture: downmixing \(inputFormat.channelCount)-channel input to mono")
        }

        let mixer = AVAudioMixerNode()
        mixer.volume = 1.0
        engine.attach(mixer)
        engine.connect(input, to: mixer, format: captureFormat)

        engine.prepare()

        // Per-stream state owned by the audio queue.
        let processor = MicAudioProcessor(captureFormat: captureFormat)
        let onPCM16 = self.onPCM16
        let onFloat32 = self.onFloat32
        let queue = audioQueue

        mixer.installTap(onBus: 0, bufferSize: MicAudioConstants.captureBufferSize, format: captureFormat) { buffer, _ in
            queue.async {
                processor.process(buffer: buffer, onFloat32: onFloat32, onPCM16: onPCM16)
            }
        }

        try engine.start()
        self.engine = engine
        self.tapNode = mixer
        self.isStreaming = true
        logInfo("MicCapture: started")
    }

    @MainActor
    func stop() {
        guard isStreaming else { return }
        engine?.stop()
        tapNode?.removeTap(onBus: 0)
        tapNode = nil
        engine = nil
        isStreaming = false
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
    private let converter = AudioSampleConverter()
    private var lastAboveThresholdTime = Date()
    #if DEBUG
    private var debugChunkCount = 0
    #endif

    init(captureFormat: AVAudioFormat) {
        self.captureFormat = captureFormat
    }

    func process(
        buffer: AVAudioPCMBuffer,
        onFloat32: (@Sendable (UnsafePointer<Float>, Int) -> Void)?,
        onPCM16: (@Sendable (Data) -> Void)?
    ) {
        guard let final = converter.convert(buffer, from: captureFormat), let floatData = final.floatChannelData else { return }
        let frameCount = Int(final.frameLength)
        guard frameCount > 0 else { return }

        let threshold = MicAudioConstants.noiseGateThreshold
        let holdTime = MicAudioConstants.noiseGateHoldTime
        let now = Date()
        let rms = AudioSampleConverter.rms(floatData[0], frameCount: frameCount)
        var gated = false

        // Debug WAVs should show what the mic produced before the local noise gate mutates it.
        onFloat32?(floatData[0], frameCount)

        if rms >= threshold {
            lastAboveThresholdTime = now
        } else if now.timeIntervalSince(lastAboveThresholdTime) >= holdTime {
            for i in 0..<frameCount { floatData[0][i] = 0 }
            gated = true
        }

        #if DEBUG
        if debugChunkCount < 6 {
            let outputRMS = AudioSampleConverter.rms(floatData[0], frameCount: frameCount)
            logInfo(
                "MicCapture: chunk \(debugChunkCount + 1) input=\(formatSummary(captureFormat)) frames=\(buffer.frameLength) convertedFrames=\(frameCount) rms=\(rms) outputRMS=\(outputRMS) threshold=\(threshold) gated=\(gated)"
            )
            debugChunkCount += 1
        }
        #endif

        onPCM16?(AudioSampleConverter.pcm16Data(floatData[0], frameCount: frameCount))
    }

    #if DEBUG
    private func formatSummary(_ format: AVAudioFormat) -> String {
        "\(Int(format.sampleRate))Hz/\(format.channelCount)ch/\(format.commonFormat)/interleaved=\(format.isInterleaved)"
    }
    #endif
}
