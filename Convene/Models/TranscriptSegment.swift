import Foundation

/// A single chunk of transcript from one speaker stream.
/// Multiple deltas merge into a final segment; live deltas may be replaced as more arrives.
struct TranscriptSegment: Identifiable, Codable, Equatable, Hashable {
    enum Speaker: String, Codable {
        case you
        case others

        var displayName: String {
            switch self {
            case .you: return "You"
            case .others: return "Others"
            }
        }
    }

    let id: UUID
    let speaker: Speaker
    /// Seconds since meeting start when this segment began.
    let startedAt: TimeInterval
    /// Seconds since meeting start when this segment ended (or last updated for in-flight deltas).
    var endedAt: TimeInterval
    var text: String
    /// False while the server is still streaming deltas; true after `transcription.completed`.
    var isFinal: Bool

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
