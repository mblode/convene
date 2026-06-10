import AVFoundation
import Foundation

enum MicRecorderConstants {
    static let sampleRate: Double = 24000
    static let captureBufferSize: AVAudioFrameCount = 1024
    static let channels: AVAudioChannelCount = 1
}

@MainActor
final class MicRecorder: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var permissionGranted = false
    @Published private(set) var lastError: String?

    var onAudioBuffer: (@Sendable (AVAudioPCMBuffer) -> Void)?

    private var engine: AVAudioEngine?
    private var mixer: AVAudioMixerNode?
    private let audioQueue = DispatchQueue(label: "co.blode.convene.mobile.mic")

    init() {
        checkPermission()
    }

    func checkPermission() {
        permissionGranted = AVAudioApplication.shared.recordPermission == .granted
    }

    func requestPermission() async -> Bool {
        let granted = await AVAudioApplication.requestRecordPermission()
        permissionGranted = granted
        return granted
    }

    func start() throws {
        guard !isRecording else { return }
        guard permissionGranted else {
            throw NSError(domain: "co.blode.convene.mobile", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Microphone permission denied"])
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .defaultToSpeaker])
        try session.setActive(true)

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.channelCount > 0, inputFormat.sampleRate > 0 else {
            throw NSError(domain: "co.blode.convene.mobile", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid audio input format"])
        }

        let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: MicRecorderConstants.sampleRate,
            channels: MicRecorderConstants.channels,
            interleaved: false
        )!

        let captureFormat: AVAudioFormat
        if inputFormat.channelCount == MicRecorderConstants.channels {
            captureFormat = inputFormat
        } else {
            captureFormat = AVAudioFormat(
                standardFormatWithSampleRate: inputFormat.sampleRate,
                channels: MicRecorderConstants.channels
            ) ?? targetFormat
        }

        let mixerNode = AVAudioMixerNode()
        mixerNode.volume = 1.0
        engine.attach(mixerNode)
        engine.connect(input, to: mixerNode, format: captureFormat)
        engine.prepare()

        let converter: AVAudioConverter? = captureFormat != targetFormat
            ? AVAudioConverter(from: captureFormat, to: targetFormat)
            : nil

        let onAudioBuffer = self.onAudioBuffer
        let queue = audioQueue

        mixerNode.installTap(onBus: 0, bufferSize: MicRecorderConstants.captureBufferSize, format: captureFormat) { buffer, _ in
            queue.async {
                let finalBuffer: AVAudioPCMBuffer
                if let converter {
                    let frameCount = AVAudioFrameCount(
                        ceil(Float(buffer.frameLength) * Float(targetFormat.sampleRate) / Float(captureFormat.sampleRate))
                    )
                    guard let out = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCount) else { return }
                    var error: NSError?
                    var consumed = false
                    converter.convert(to: out, error: &error) { _, status in
                        if consumed { status.pointee = .noDataNow; return nil }
                        consumed = true
                        status.pointee = .haveData
                        return buffer
                    }
                    guard error == nil else { return }
                    finalBuffer = out
                } else {
                    finalBuffer = buffer
                }

                guard finalBuffer.frameLength > 0 else { return }
                onAudioBuffer?(finalBuffer)
            }
        }

        try engine.start()
        self.engine = engine
        self.mixer = mixerNode
        isRecording = true
        lastError = nil
        logInfo("MicRecorder: started (24kHz float32 mono)")
    }

    func stop() {
        guard isRecording else { return }
        engine?.stop()
        mixer?.removeTap(onBus: 0)
        mixer = nil
        engine = nil
        isRecording = false
        logInfo("MicRecorder: stopped")
    }
}
