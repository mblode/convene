import Foundation

/// Pure helpers for the Live Recap surface (`⌘?`): a glanceable last-N-minutes view of the
/// meeting, interleaved with the moments you've flagged. Deliberately *pull*, never push —
/// the UI summons it, nothing here suggests proactively.
enum LiveRecap {
    /// One entry in the glanceable recap timeline, ordered oldest-first by offset.
    enum Item: Equatable, Identifiable {
        case moment(KeyMoment)
        case block(TranscriptFormatter.Block)

        var id: String {
            switch self {
            case .moment(let moment):
                return "moment:\(moment.id.uuidString)"
            case .block(let block):
                return "block:\(Int(block.startedAt * 1000)):\(block.speaker.rawValue):\(block.text.count)"
            }
        }

        /// Meeting-relative start used for ordering.
        var startedAt: TimeInterval {
            switch self {
            case .moment(let moment): return moment.offset
            case .block(let block): return block.startedAt
            }
        }
    }

    /// The default recap lookback — the "last two minutes" the roadmap calls for.
    static let defaultWindow: TimeInterval = 120

    /// Builds the recap timeline: transcript blocks overlapping the trailing `window` seconds,
    /// interleaved with any key moments flagged in that window, oldest-first.
    ///
    /// - Parameters:
    ///   - segments: live transcript segments (echo duplicates are removed here).
    ///   - keyMoments: flagged moments for the meeting.
    ///   - now: current meeting offset in seconds (defines the window's right edge).
    ///   - window: lookback duration.
    static func timeline(
        segments: [TranscriptSegment],
        keyMoments: [KeyMoment],
        now: TimeInterval,
        window: TimeInterval = defaultWindow
    ) -> [Item] {
        let cutoff = max(0, now - window)

        let cleaned = segments
            .removingLikelyEchoDuplicates()
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let blocks = TranscriptFormatter.mergedBlocks(cleaned)
            .filter { $0.endedAt >= cutoff }
            .map(Item.block)

        let moments = keyMoments
            .filter { $0.offset >= cutoff }
            .map(Item.moment)

        return (blocks + moments).sorted { lhs, rhs in
            if lhs.startedAt == rhs.startedAt {
                // Show a moment ahead of a block that starts at the same instant so the flag
                // reads as marking what follows.
                if case .moment = lhs, case .block = rhs { return true }
                if case .block = lhs, case .moment = rhs { return false }
            }
            return lhs.startedAt < rhs.startedAt
        }
    }

    /// Compact transcript text for the recap window, used as input to an optional AI recap.
    /// Returns nil when the window holds nothing worth summarizing.
    static func transcriptText(
        segments: [TranscriptSegment],
        now: TimeInterval,
        window: TimeInterval = defaultWindow
    ) -> String? {
        let lines = timeline(segments: segments, keyMoments: [], now: now, window: window)
            .compactMap { item -> String? in
                guard case .block(let block) = item else { return nil }
                return "\(TranscriptFormatter.timestampString(block.startedAt)) \(block.speaker.displayName): \(block.text)"
            }
        let joined = lines.joined(separator: "\n")
        return joined.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : joined
    }
}
