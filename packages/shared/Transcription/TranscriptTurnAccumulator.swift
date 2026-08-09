import Foundation

/// Folds AssemblyAI `Turn` and `SpeakerRevision` messages into an ordered `TranscriptSegment`
/// list. Owns the mutable turn-mapping state (segments plus the per-turn ID and per-speaker
/// connect-offset lookups) that used to live in the transcriber; the coordinator keeps the
/// sockets and republishes `segments` after each mutation.
struct TranscriptTurnAccumulator {
    private(set) var segments: [TranscriptSegment] = []
    private var segmentIDsByTurnKey: [String: UUID] = [:]
    private var connectElapsedBySpeaker: [String: TimeInterval] = [:]

    /// Clear all state for a new session.
    mutating func reset() {
        segments = []
        segmentIDsByTurnKey = [:]
        connectElapsedBySpeaker = [:]
    }

    /// Record a stream's `Begin` offset — AssemblyAI word times are relative to session start,
    /// so segment times are this offset plus the word time.
    mutating func recordConnect(speaker: TranscriptSegment.Speaker, elapsed: TimeInterval) {
        connectElapsedBySpeaker[speaker.rawValue] = elapsed
    }

    /// Fold a turn into `segments`. Returns the finalized segment when one was confirmed (so the
    /// caller can fire onSegmentConfirmed + append to the WAL), otherwise nil.
    mutating func handleTurn(
        _ turn: AssemblyAITurnMessage,
        speaker: TranscriptSegment.Speaker,
        currentElapsed: TimeInterval
    ) -> TranscriptSegment? {
        let text = turn.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = turnKey(speaker: speaker, turnOrder: turn.turnOrder)
        let connectElapsed = connectElapsedBySpeaker[speaker.rawValue] ?? 0
        let startedAt = turn.words.first.map { connectElapsed + TimeInterval($0.start) / 1000 }
            ?? currentElapsed
        let endedAt = turn.words.last.map { connectElapsed + TimeInterval($0.end) / 1000 }
            ?? currentElapsed
        let diarized = Self.diarizedSpeaker(from: turn.speakerLabel)

        guard turn.endOfTurn else {
            guard !text.isEmpty else { return nil }
            // Partials carry the full turn text so far: replace, never append.
            if let id = segmentIDsByTurnKey[key],
               let index = segments.firstIndex(where: { $0.id == id }) {
                segments[index].text = text
                segments[index].endedAt = endedAt
                segments[index].diarizedSpeaker = diarized
                return nil
            }
            let segment = TranscriptSegment(
                speaker: speaker,
                startedAt: startedAt,
                endedAt: endedAt,
                text: text,
                isFinal: false,
                diarizedSpeaker: diarized
            )
            segmentIDsByTurnKey[key] = segment.id
            segments.append(segment)
            return nil
        }

        // Finalized + formatted turn.
        if text.isEmpty {
            // Empty final turn: drop any partial we accumulated for it.
            if let id = segmentIDsByTurnKey.removeValue(forKey: key) {
                segments.removeAll { $0.id == id }
            }
            return nil
        }

        let finalized: TranscriptSegment
        if let id = segmentIDsByTurnKey[key],
           let index = segments.firstIndex(where: { $0.id == id }) {
            segments[index].text = text
            segments[index].endedAt = endedAt
            segments[index].isFinal = true
            if diarized != nil {
                segments[index].diarizedSpeaker = diarized
            }
            finalized = segments[index]
        } else {
            let segment = TranscriptSegment(
                speaker: speaker,
                startedAt: startedAt,
                endedAt: endedAt,
                text: text,
                isFinal: true,
                diarizedSpeaker: diarized
            )
            segmentIDsByTurnKey[key] = segment.id
            segments.append(segment)
            finalized = segment
        }

        switch TranscriptSegment.resolveEchoDuplicate(for: finalized, in: segments) {
        case .dropCandidate:
            logInfo(
                "TranscriptTurnAccumulator: suppressed likely echo duplicate \(speaker.displayName) segment; kept existing copy"
            )
            segments.removeAll { $0.id == finalized.id }
            segmentIDsByTurnKey.removeValue(forKey: key)
            return nil
        case .evictExisting(let duplicateID):
            logInfo(
                "TranscriptTurnAccumulator: suppressed likely echo duplicate matching \(speaker.displayName); kept \(speaker.displayName) copy"
            )
            evictSegment(withID: duplicateID)
        case .keep:
            break
        }

        return finalized
    }

    mutating func applySpeakerRevision(
        _ revision: AssemblyAISpeakerRevisionMessage,
        speaker: TranscriptSegment.Speaker
    ) {
        guard !revision.revisions.isEmpty else { return }
        var applied = 0
        for (turnOrder, label) in revision.revisions {
            let key = turnKey(speaker: speaker, turnOrder: turnOrder)
            guard let id = segmentIDsByTurnKey[key],
                  let index = segments.firstIndex(where: { $0.id == id }) else { continue }
            segments[index].diarizedSpeaker = Self.diarizedSpeaker(from: label)
            applied += 1
        }
        logInfo("TranscriptTurnAccumulator[\(speaker.rawValue)]: applied speaker revision to \(applied) turn(s)")
    }

    private mutating func evictSegment(withID id: UUID) {
        segments.removeAll { $0.id == id }
        if let staleKey = segmentIDsByTurnKey.first(where: { $0.value == id })?.key {
            segmentIDsByTurnKey.removeValue(forKey: staleKey)
        }
    }

    private func turnKey(speaker: TranscriptSegment.Speaker, turnOrder: Int) -> String {
        "\(speaker.rawValue):\(turnOrder)"
    }

    private static func diarizedSpeaker(from label: String?) -> String? {
        guard let label, !label.isEmpty, label.uppercased() != "UNKNOWN" else { return nil }
        return label
    }
}
