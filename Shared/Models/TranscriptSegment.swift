import Foundation

struct TranscriptSegment: Identifiable, Codable, Equatable, Hashable {
    enum Speaker: Codable, Equatable, Hashable {
        case you
        case others
        case named(String)

        var displayName: String {
            switch self {
            case .you: return "You"
            case .others: return "Others"
            case .named(let name): return name
            }
        }

        var rawValue: String {
            switch self {
            case .you: return "you"
            case .others: return "others"
            case .named(let name): return name
            }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            switch value {
            case "you": self = .you
            case "others": self = .others
            default: self = .named(value)
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
        }
    }

    let id: UUID
    let speaker: Speaker
    let startedAt: TimeInterval
    var endedAt: TimeInterval
    var text: String
    var isFinal: Bool
    /// Diarization label from the streaming provider (e.g. "A", "B") on system-audio
    /// segments. nil when diarization is unavailable or the provider reported UNKNOWN.
    /// Optional so legacy persisted JSON without the key still decodes.
    var diarizedSpeaker: String?

    var formattedTimestamp: String {
        let mm = Int(startedAt) / 60
        let ss = Int(startedAt) % 60
        return String(format: "[%02d:%02d]", mm, ss)
    }

    init(id: UUID = UUID(),
         speaker: Speaker,
         startedAt: TimeInterval,
         endedAt: TimeInterval,
         text: String,
         isFinal: Bool,
         diarizedSpeaker: String? = nil) {
        self.id = id
        self.speaker = speaker
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.text = text
        self.isFinal = isFinal
        self.diarizedSpeaker = diarizedSpeaker
    }
}

extension TranscriptSegment {
    private static let echoWindow: TimeInterval = 8.0
    private static let echoPadding: TimeInterval = 1.0
    private static let minimumEchoCharacters = 16
    private static let minimumEchoTokens = 4
    private static let echoTokenCoverage = 0.60
    private static let echoLengthRatio = 0.50

    /// Outcome of cross-stream echo dedup when a segment finalizes.
    enum EchoDedupResolution: Equatable {
        /// No likely duplicate; keep the finalized segment and confirm it.
        case keep
        /// An existing copy is preferred (.others wins over .you); drop the finalized
        /// candidate and clean up its key bookkeeping.
        case dropCandidate
        /// The finalized candidate is preferred; evict the existing duplicate with this
        /// id (and any stale key bookkeeping pointing at it) before confirming.
        case evictExisting(UUID)
    }

    /// Echo-dedup decision for a just-finalized segment against the live segment list.
    /// Encapsulates the preference rule (`preferredCopy`, .others wins) so every
    /// transcriber applies identical suppression. The candidate may already be present
    /// in `segments`; it is excluded from matching by id.
    static func resolveEchoDuplicate(
        for candidate: TranscriptSegment,
        in segments: [TranscriptSegment]
    ) -> EchoDedupResolution {
        guard let duplicate = likelyEchoDuplicate(for: candidate, in: segments, excluding: candidate.id) else {
            return .keep
        }
        let preferred = preferredCopy(duplicate, candidate)
        return preferred.id == candidate.id ? .evictExisting(duplicate.id) : .dropCandidate
    }

    static func likelyEchoDuplicate(
        for candidate: TranscriptSegment,
        in segments: [TranscriptSegment],
        excluding excludedID: UUID? = nil
    ) -> TranscriptSegment? {
        segments.first { existing in
            if let excludedID, existing.id == excludedID { return false }
            return isLikelyEchoDuplicate(candidate, of: existing)
        }
    }

    static func isLikelyEchoDuplicate(_ candidate: TranscriptSegment, of existing: TranscriptSegment) -> Bool {
        guard candidate.isFinal, existing.isFinal else { return false }
        guard candidate.speaker != existing.speaker else { return false }
        guard isTemporallyClose(candidate, existing) else { return false }

        let candidateText = normalizedEchoText(candidate.text)
        let existingText = normalizedEchoText(existing.text)
        guard candidateText.count >= minimumEchoCharacters,
              existingText.count >= minimumEchoCharacters else { return false }

        if candidateText == existingText {
            return true
        }

        let candidateTokens = candidateText.split(separator: " ").map(String.init)
        let existingTokens = existingText.split(separator: " ").map(String.init)
        guard min(candidateTokens.count, existingTokens.count) >= minimumEchoTokens else { return false }

        let (shorter, longer) = candidateTokens.count <= existingTokens.count
            ? (candidateTokens, existingTokens)
            : (existingTokens, candidateTokens)
        var consumed = [Bool](repeating: false, count: longer.count)
        var matchedCount = 0
        for token in shorter {
            if let index = longer.indices.first(where: { !consumed[$0] && echoTokensMatch(token, longer[$0]) }) {
                consumed[index] = true
                matchedCount += 1
            }
        }

        let coverage = Double(matchedCount) / Double(shorter.count)
        let lengthRatio = Double(min(candidateText.count, existingText.count)) /
            Double(max(candidateText.count, existingText.count))
        return coverage >= echoTokenCoverage && lengthRatio >= echoLengthRatio
    }

    /// Two tokens match when equal, or — for tokens of at least four characters —
    /// within Levenshtein distance 1 or sharing the same first four characters.
    static func echoTokensMatch(_ lhs: String, _ rhs: String) -> Bool {
        if lhs == rhs { return true }
        guard lhs.count >= 4, rhs.count >= 4 else { return false }
        if lhs.prefix(4) == rhs.prefix(4) { return true }
        return levenshteinDistance(lhs, rhs) <= 1
    }

    /// For a {.you, .others} duplicate pair the .others copy is the correct one:
    /// bleed only flows system audio -> mic, never the other way around.
    /// Otherwise prefer the earlier copy.
    static func preferredCopy(_ a: TranscriptSegment, _ b: TranscriptSegment) -> TranscriptSegment {
        if a.speaker == .others, b.speaker == .you { return a }
        if a.speaker == .you, b.speaker == .others { return b }
        return a.startedAt <= b.startedAt ? a : b
    }

    private static func levenshteinDistance(_ lhs: String, _ rhs: String) -> Int {
        let a = Array(lhs)
        let b = Array(rhs)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }

        var previous = Array(0...b.count)
        for (i, charA) in a.enumerated() {
            var current = [i + 1]
            current.reserveCapacity(b.count + 1)
            for (j, charB) in b.enumerated() {
                let substitution = previous[j] + (charA == charB ? 0 : 1)
                current.append(Swift.min(previous[j + 1] + 1, current[j] + 1, substitution))
            }
            previous = current
        }
        return previous[b.count]
    }

    private static func isTemporallyClose(_ lhs: TranscriptSegment, _ rhs: TranscriptSegment) -> Bool {
        if abs(lhs.startedAt - rhs.startedAt) <= echoWindow {
            return true
        }
        return lhs.startedAt <= rhs.endedAt + echoPadding &&
            rhs.startedAt <= lhs.endedAt + echoPadding
    }

    private static func normalizedEchoText(_ text: String) -> String {
        var normalized = text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()

        for (word, digit) in [
            ("zero", "0"),
            ("one", "1"),
            ("two", "2"),
            ("three", "3"),
            ("four", "4"),
            ("five", "5"),
            ("six", "6"),
            ("seven", "7"),
            ("eight", "8"),
            ("nine", "9"),
            ("ten", "10")
        ] {
            normalized = normalized.replacingOccurrences(
                of: "\\b\(word)\\b",
                with: digit,
                options: .regularExpression
            )
        }

        return normalized
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension Array where Element == TranscriptSegment {
    func chronologicallySorted() -> [TranscriptSegment] {
        enumerated()
            .sorted { lhs, rhs in
                if lhs.element.startedAt == rhs.element.startedAt {
                    return lhs.offset < rhs.offset
                }
                return lhs.element.startedAt < rhs.element.startedAt
            }
            .map(\.element)
    }

    func removingLikelyEchoDuplicates() -> [TranscriptSegment] {
        var kept: [TranscriptSegment] = []
        for segment in chronologicallySorted() {
            guard let index = kept.firstIndex(where: { TranscriptSegment.isLikelyEchoDuplicate(segment, of: $0) }) else {
                kept.append(segment)
                continue
            }
            let preferred = TranscriptSegment.preferredCopy(kept[index], segment)
            if preferred.id == segment.id {
                kept.remove(at: index)
                kept.append(segment)
            }
        }
        return kept
    }
}
