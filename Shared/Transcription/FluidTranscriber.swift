import AVFoundation
import Combine
import FluidAudio
import Foundation

@MainActor
final class FluidTranscriber: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var isLoadingModels = false
    @Published private(set) var segments: [TranscriptSegment] = []
    @Published private(set) var lastError: String?
    var onSegmentConfirmed: ((TranscriptSegment) -> Void)?

    private var asrManager: SlidingWindowAsrManager?
    private var diarizer: SortformerDiarizer?
    private var updateTask: Task<Void, Never>?
    private var meetingStartedAt: Date?
    private var audioSubmissionTask: Task<Void, Never>?
    private var audioStream: AsyncStream<AVAudioPCMBuffer>?
    private nonisolated(unsafe) var audioContinuation: AsyncStream<AVAudioPCMBuffer>.Continuation?

    private let pcmFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 16000,
        channels: 1,
        interleaved: false
    )!

    func start() async {
        guard !isRunning else { return }
        lastError = nil
        segments = []
        meetingStartedAt = Date()

        do {
            isLoadingModels = true
            let asr = SlidingWindowAsrManager(config: .streaming)
            try await asr.loadModels()

            let sortformerModels = try await SortformerModels.loadFromHuggingFace(config: .default)
            let diar = SortformerDiarizer()
            diar.initialize(models: sortformerModels)
            isLoadingModels = false

            try await asr.startStreaming()

            let (stream, continuation) = AsyncStream<AVAudioPCMBuffer>.makeStream()
            self.audioStream = stream
            self.audioContinuation = continuation
            self.asrManager = asr
            self.diarizer = diar
            self.isRunning = true
            logInfo("FluidTranscriber: started (streaming ASR + Sortformer diarization)")

            subscribeToUpdates(asr)
            startAudioSubmission(asr: asr, diarizer: diar, stream: stream)
        } catch {
            isLoadingModels = false
            lastError = "Failed to start transcription: \(error.localizedDescription)"
            logError("FluidTranscriber: start failed: \(error.localizedDescription)")
            asrManager = nil
            diarizer = nil
        }
    }

    nonisolated func ingestAudio(_ buffer: AVAudioPCMBuffer) {
        audioContinuation?.yield(buffer)
    }

    nonisolated func ingestPCM16(_ data: Data) {
        let sampleCount = data.count / 2
        guard sampleCount > 0 else { return }
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleCount)) else { return }
        buffer.frameLength = AVAudioFrameCount(sampleCount)
        guard let channelData = buffer.floatChannelData else { return }
        data.withUnsafeBytes { raw in
            let int16s = raw.bindMemory(to: Int16.self)
            for i in 0..<sampleCount {
                channelData[0][i] = Float(Int16(littleEndian: int16s[i])) / 32768.0
            }
        }
        audioContinuation?.yield(buffer)
    }

    func stop() async {
        guard isRunning else { return }
        audioContinuation?.finish()
        audioContinuation = nil
        updateTask?.cancel()
        audioSubmissionTask?.cancel()

        if let asr = asrManager {
            do {
                let finalText = try await asr.finish()
                if !finalText.isEmpty {
                    appendSegment(text: finalText, isConfirmed: true)
                }
            } catch {
                logError("FluidTranscriber: finish failed: \(error.localizedDescription)")
            }
        }

        if let diar = diarizer {
            do {
                _ = try diar.finalizeSession()
            } catch {
                logError("FluidTranscriber: diarizer finalize failed: \(error.localizedDescription)")
            }
            applySpeakerLabels(from: diar.timeline)
            diar.cleanup()
        }

        isRunning = false
        asrManager = nil
        diarizer = nil
        updateTask = nil
        audioSubmissionTask = nil
        audioStream = nil
        logInfo("FluidTranscriber: stopped (\(segments.count) segments)")
    }

    // MARK: - Audio submission (off main thread)

    private func startAudioSubmission(asr: SlidingWindowAsrManager, diarizer: SortformerDiarizer, stream: AsyncStream<AVAudioPCMBuffer>) {
        audioSubmissionTask = Task.detached { [weak self] in
            for await buffer in stream {
                guard !Task.isCancelled else { break }
                await asr.streamAudio(buffer)

                guard let floats = buffer.floatChannelData?[0] else { continue }
                let count = Int(buffer.frameLength)
                let samples = Array(UnsafeBufferPointer(start: floats, count: count))
                do {
                    try diarizer.addAudio(samples, sourceSampleRate: 16000)
                    _ = try diarizer.process()
                } catch {
                    await MainActor.run { [weak self] in
                        self?.lastError = "Diarization error: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    // MARK: - Streaming updates

    private func subscribeToUpdates(_ asr: SlidingWindowAsrManager) {
        updateTask = Task { [weak self] in
            let stream = await asr.transcriptionUpdates
            for await update in stream {
                guard !Task.isCancelled else { break }
                await MainActor.run { [weak self] in
                    self?.handleUpdate(update)
                }
            }
        }
    }

    private func handleUpdate(_ update: SlidingWindowTranscriptionUpdate) {
        let text = update.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let startTime: TimeInterval
        let endTime: TimeInterval
        if let first = update.tokenTimings.first, let last = update.tokenTimings.last {
            startTime = first.startTime
            endTime = last.endTime
        } else {
            let elapsed = meetingStartedAt.map { Date().timeIntervalSince($0) } ?? 0
            startTime = elapsed
            endTime = elapsed
        }

        if update.isConfirmed {
            if let lastIndex = segments.indices.last, !segments[lastIndex].isFinal {
                segments.removeLast()
            }
            appendSegment(text: text, startTime: startTime, endTime: endTime, isConfirmed: true)
            if let last = segments.last { onSegmentConfirmed?(last) }
        } else {
            if let lastIndex = segments.indices.last, !segments[lastIndex].isFinal {
                segments[lastIndex].text = text
                segments[lastIndex].endedAt = endTime
            } else {
                appendSegment(text: text, startTime: startTime, endTime: endTime, isConfirmed: false)
            }
        }
    }

    private func appendSegment(text: String, startTime: TimeInterval = 0, endTime: TimeInterval = 0, isConfirmed: Bool) {
        segments.append(TranscriptSegment(
            speaker: .you,
            startedAt: startTime,
            endedAt: endTime,
            text: text,
            isFinal: isConfirmed
        ))
    }

    // MARK: - Diarization

    private func applySpeakerLabels(from timeline: DiarizerTimeline) {
        let speakers = timeline.speakers
        guard !speakers.isEmpty else { return }

        var allDiarSegments: [(name: String, start: Float, end: Float)] = []
        for (_, speaker) in speakers {
            let name = speaker.name ?? "Speaker \(speaker.index + 1)"
            for seg in speaker.finalizedSegments {
                allDiarSegments.append((name: name, start: seg.startTime, end: seg.endTime))
            }
            for seg in speaker.tentativeSegments {
                allDiarSegments.append((name: name, start: seg.startTime, end: seg.endTime))
            }
        }
        guard !allDiarSegments.isEmpty else { return }
        allDiarSegments.sort { $0.start < $1.start }

        var diarIdx = 0
        for i in segments.indices {
            let segStart = Float(segments[i].startedAt)
            let segEnd = Float(segments[i].endedAt)

            while diarIdx > 0 && allDiarSegments[diarIdx].start > segStart {
                diarIdx -= 1
            }

            var bestName: String?
            var bestOverlap: Float = 0

            for j in diarIdx..<allDiarSegments.count {
                let diar = allDiarSegments[j]
                if diar.start > segEnd + 2.0 { break }

                let overlapStart = max(segStart, diar.start)
                let overlapEnd = min(segEnd, diar.end)
                let overlap = max(0, overlapEnd - overlapStart)

                if overlap > bestOverlap {
                    bestOverlap = overlap
                    bestName = diar.name
                }
            }

            if bestOverlap == 0 {
                let segMid = (segStart + segEnd) / 2
                for j in diarIdx..<allDiarSegments.count {
                    let diar = allDiarSegments[j]
                    if diar.start > segMid + 2.0 { break }
                    let diarMid = (diar.start + diar.end) / 2
                    if abs(segMid - diarMid) < 2.0 {
                        bestName = diar.name
                        break
                    }
                }
            }

            if let name = bestName {
                segments[i] = TranscriptSegment(
                    id: segments[i].id,
                    speaker: .named(name),
                    startedAt: segments[i].startedAt,
                    endedAt: segments[i].endedAt,
                    text: segments[i].text,
                    isFinal: segments[i].isFinal
                )
            }
        }
    }
}
