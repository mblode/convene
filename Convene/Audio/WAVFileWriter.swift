import Foundation
import AVFoundation

/// Minimal Float32 mono 24 kHz WAV file writer.
/// Useful for debug dumps and the optional "save audio file" toggle.
final class WAVFileWriter {
    private let file: AVAudioFile
    private let format: AVAudioFormat

    init(url: URL) throws {
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: MicAudioConstants.sampleRate,
            channels: 1,
            interleaved: false
        )!
        self.format = format
        self.file = try AVAudioFile(
            forWriting: url,
            settings: format.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        logInfo("WAVFileWriter: writing to \(url.lastPathComponent)")
    }

    func append(samples: UnsafePointer<Float>, count: Int) {
        guard count > 0 else { return }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)) else { return }
        buffer.frameLength = AVAudioFrameCount(count)
        guard let dst = buffer.floatChannelData?[0] else { return }
        memcpy(dst, samples, count * MemoryLayout<Float>.size)
        do {
            try file.write(from: buffer)
        } catch {
            logError("WAVFileWriter: write error: \(error.localizedDescription)")
        }
    }

}
