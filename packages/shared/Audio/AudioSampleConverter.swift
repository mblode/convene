import AVFoundation
import Foundation

/// The single source of truth for the PCM format Convene streams to transcription. AssemblyAI
/// is told this sample rate on connect, so every capture path must resample to it — a mismatch
/// (e.g. sending 24 kHz audio tagged as 16 kHz) time-stretches the transcript.
enum TranscriptionAudio {
    static let sampleRate = 16_000
    static let channels: AVAudioChannelCount = 1

    /// 16 kHz mono float32, non-interleaved — what capture resamples to before packing to PCM16.
    static let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: Double(sampleRate),
        channels: channels,
        interleaved: false
    )!
}

/// Resamples capture buffers to `TranscriptionAudio.targetFormat` and packs float samples to
/// little-endian PCM16 for streaming. An instance caches one `AVAudioConverter` keyed by input
/// format (rebuilt when the format changes); the statics are stateless helpers. Not thread-safe:
/// confine an instance to a single audio queue.
final class AudioSampleConverter {
    private var converter: AVAudioConverter?
    private var inputFormat: AVAudioFormat?

    /// Resample `buffer` (in `format`) to the target format, returning the source unchanged when
    /// it already matches. Nil on converter failure.
    func convert(_ buffer: AVAudioPCMBuffer, from format: AVAudioFormat) -> AVAudioPCMBuffer? {
        if format == TranscriptionAudio.targetFormat { return buffer }
        if converter == nil || inputFormat != format {
            converter = AVAudioConverter(from: format, to: TranscriptionAudio.targetFormat)
            inputFormat = format
        }
        guard let converter else { return nil }

        let outFrames = AVAudioFrameCount(
            ceil(Double(buffer.frameLength) * TranscriptionAudio.targetFormat.sampleRate / format.sampleRate)
        )
        guard outFrames > 0,
              let out = AVAudioPCMBuffer(pcmFormat: TranscriptionAudio.targetFormat, frameCapacity: outFrames)
        else { return nil }

        var consumed = false
        var error: NSError?
        let status = converter.convert(to: out, error: &error) { _, status in
            if consumed { status.pointee = .noDataNow; return nil }
            consumed = true
            status.pointee = .haveData
            return buffer
        }
        if status == .error || error != nil {
            logError("AudioSampleConverter: conversion error: \(error?.localizedDescription ?? "unknown")")
            return nil
        }
        return out
    }

    // MARK: - Stateless helpers

    /// Little-endian PCM16 from `frameCount` float samples.
    static func pcm16Data(_ samples: UnsafePointer<Float>, frameCount: Int) -> Data {
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

    /// Little-endian PCM16 from a float32 buffer's first channel. Nil if the buffer has no data.
    static func pcm16Data(from buffer: AVAudioPCMBuffer) -> Data? {
        guard let channelData = buffer.floatChannelData?[0] else { return nil }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return nil }
        return pcm16Data(channelData, frameCount: frameCount)
    }

    /// RMS of `frameCount` float samples, normalized to 0...1.
    static func rms(_ samples: UnsafePointer<Float>, frameCount: Int) -> Float {
        guard frameCount > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<frameCount { sum += samples[i] * samples[i] }
        return (sum / Float(frameCount)).squareRoot()
    }

    /// RMS of a little-endian mono PCM16 chunk, normalized to 0...1.
    static func rms(pcm16 data: Data) -> Float {
        let sampleCount = data.count / 2
        guard sampleCount > 0 else { return 0 }
        var sum: Float = 0
        data.withUnsafeBytes { raw in
            let int16 = raw.bindMemory(to: Int16.self)
            for i in 0..<sampleCount {
                let sample = Float(Int16(littleEndian: int16[i])) / 32768.0
                sum += sample * sample
            }
        }
        return (sum / Float(sampleCount)).squareRoot()
    }
}
