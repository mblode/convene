import Foundation
import AVFoundation
import AppKit

/// One source of truth for starting/stopping a meeting recording.
/// Owns MicCapture (You) and SystemAudioCapture (Others), exposes labeled PCM16 chunk callbacks,
/// and optionally writes a mixed Float32 WAV to disk for debugging.
@MainActor
final class AudioCaptureCoordinator: ObservableObject {
    enum SpeakerStream: String {
        case you, others
    }

    @Published private(set) var isCapturing = false
    @Published private(set) var startError: String?

    let mic = MicCapture()
    let system = SystemAudioCapture()

    /// (speaker, pcm16) per chunk. Wire this to TranscriptionCoordinator.
    var onPCM16: ((SpeakerStream, Data) -> Void)?

    /// Optional debug WAV writer. When non-nil, both streams are written to separate WAV files.
    private var youWAV: WAVFileWriter?
    private var othersWAV: WAVFileWriter?

    init() {
        // Audio callbacks fire on background queues; hop to MainActor before touching state.
        mic.onPCM16 = { [weak self] data in
            Task { @MainActor [weak self] in
                self?.onPCM16?(.you, data)
            }
        }
        mic.onFloat32 = { [weak self] samples, count in
            // Float32 writer holds its own state; copy samples to a Data so we can hop safely.
            let copy = Data(bytes: samples, count: count * MemoryLayout<Float>.size)
            Task { @MainActor [weak self] in
                self?.appendYouFloat32(copy: copy)
            }
        }
        system.onPCM16 = { [weak self] data in
            Task { @MainActor [weak self] in
                self?.onPCM16?(.others, data)
            }
        }
        system.onFloat32 = { [weak self] samples, count in
            let copy = Data(bytes: samples, count: count * MemoryLayout<Float>.size)
            Task { @MainActor [weak self] in
                self?.appendOthersFloat32(copy: copy)
            }
        }
        system.onStoppedWithError = { [weak self] error in
            Task { @MainActor [weak self] in
                await self?.handleSystemError(error)
            }
        }
    }

    private func appendYouFloat32(copy: Data) {
        guard let writer = youWAV else { return }
        copy.withUnsafeBytes { raw in
            guard let base = raw.baseAddress?.assumingMemoryBound(to: Float.self) else { return }
            writer.append(samples: base, count: copy.count / MemoryLayout<Float>.size)
        }
    }

    private func appendOthersFloat32(copy: Data) {
        guard let writer = othersWAV else { return }
        copy.withUnsafeBytes { raw in
            guard let base = raw.baseAddress?.assumingMemoryBound(to: Float.self) else { return }
            writer.append(samples: base, count: copy.count / MemoryLayout<Float>.size)
        }
    }

    /// Start capturing. Optionally provide a base URL — if set, two WAV files
    /// (`<base>-you.wav`, `<base>-others.wav`) are written for debug.
    func start(debugWAVBaseURL: URL? = nil) async {
        guard !isCapturing else { return }
        startError = nil

        guard await requestPermissions() else { return }

        if let base = debugWAVBaseURL {
            youWAV = try? WAVFileWriter(url: base.appendingPathExtension("you.wav"))
            othersWAV = try? WAVFileWriter(url: base.appendingPathExtension("others.wav"))
        }

        do {
            try mic.start()
        } catch {
            cleanupWriters()
            startError = "Mic start failed: \(error.localizedDescription)"
            return
        }

        do {
            try await system.start()
        } catch {
            mic.stop()
            cleanupWriters()
            startError = "System audio start failed: \(error.localizedDescription)"
            return
        }

        isCapturing = true
        logInfo("AudioCaptureCoordinator: capturing both streams")
    }

    func stop() async {
        guard isCapturing else { return }
        mic.stop()
        mic.flushPendingAudio()
        await system.stop()
        cleanupWriters()
        isCapturing = false
        logInfo("AudioCaptureCoordinator: stopped")
    }

    @discardableResult
    func requestPermissions() async -> Bool {
        startError = nil

        guard await ensureMicPermission() else {
            startError = "Microphone permission required"
            return false
        }

        guard await system.requestPermission() else {
            startError = "Screen recording permission required"
            return false
        }

        return true
    }

    private func ensureMicPermission() async -> Bool {
        await mic.requestPermission()
    }

    private func cleanupWriters() {
        youWAV = nil
        othersWAV = nil
    }

    private func handleSystemError(_ error: Error) async {
        if isCapturing {
            await stop()
        }
        startError = "System audio stopped: \(error.localizedDescription)"
    }
}
