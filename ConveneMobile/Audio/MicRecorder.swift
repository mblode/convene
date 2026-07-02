import AVFoundation
import Foundation

enum MicRecorderConstants {
    static let captureBufferSize: AVAudioFrameCount = 1024
}

@MainActor
final class MicRecorder: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var permissionGranted = false
    @Published private(set) var lastError: String?

    /// Emits 16 kHz mono PCM16 chunks (the format AssemblyAI is told to expect). Called from a
    /// background audio queue.
    var onPCM16: (@Sendable (Data) -> Void)?

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

        let captureFormat: AVAudioFormat
        if inputFormat.channelCount == TranscriptionAudio.channels {
            captureFormat = inputFormat
        } else {
            captureFormat = AVAudioFormat(
                standardFormatWithSampleRate: inputFormat.sampleRate,
                channels: TranscriptionAudio.channels
            ) ?? TranscriptionAudio.targetFormat
        }

        let mixerNode = AVAudioMixerNode()
        mixerNode.volume = 1.0
        engine.attach(mixerNode)
        engine.connect(input, to: mixerNode, format: captureFormat)
        engine.prepare()

        let converter = AudioSampleConverter()
        let onPCM16 = self.onPCM16
        let queue = audioQueue

        mixerNode.installTap(onBus: 0, bufferSize: MicRecorderConstants.captureBufferSize, format: captureFormat) { buffer, _ in
            queue.async {
                guard let out = converter.convert(buffer, from: captureFormat),
                      let data = AudioSampleConverter.pcm16Data(from: out) else { return }
                onPCM16?(data)
            }
        }

        try engine.start()
        self.engine = engine
        self.mixer = mixerNode
        isRecording = true
        lastError = nil
        logInfo("MicRecorder: started (16kHz PCM16 mono)")
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
