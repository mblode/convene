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
