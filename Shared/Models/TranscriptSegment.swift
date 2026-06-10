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
         isFinal: Bool) {
        self.id = id
        self.speaker = speaker
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.text = text
        self.isFinal = isFinal
    }
}

extension TranscriptSegment {
    private static let echoWindow: TimeInterval = 2.5
    private static let echoPadding: TimeInterval = 1.0
    private static let minimumEchoCharacters = 12
    private static let minimumEchoTokens = 3
    private static let echoTokenCoverage = 0.86
    private static let echoLengthRatio = 0.70

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

        let candidateTokens = Set(candidateText.split(separator: " ").map(String.init))
        let existingTokens = Set(existingText.split(separator: " ").map(String.init))
        let minimumTokenCount = min(candidateTokens.count, existingTokens.count)
        guard minimumTokenCount >= minimumEchoTokens else { return false }

        let sharedCount = candidateTokens.intersection(existingTokens).count
        let coverage = Double(sharedCount) / Double(minimumTokenCount)
        let lengthRatio = Double(min(candidateText.count, existingText.count)) /
            Double(max(candidateText.count, existingText.count))
        return coverage >= echoTokenCoverage && lengthRatio >= echoLengthRatio
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
            if TranscriptSegment.likelyEchoDuplicate(for: segment, in: kept) == nil {
                kept.append(segment)
            }
        }
        return kept
    }
}
