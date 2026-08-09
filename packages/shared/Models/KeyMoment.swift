import Foundation

/// A timestamped, human-marked flag dropped live during a meeting with a hotkey.
///
/// Key moments encode *human judgment* ("this matters") that no model inference replaces —
/// they're what makes Convene an annotation layer rather than passive transcription. Each
/// moment anchors to a meeting-relative `offset` so it can be linked back to the exact spot
/// in the rendered transcript.
struct KeyMoment: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    /// Meeting-relative offset, in seconds, where the moment was flagged. Mirrors
    /// `TranscriptSegment.startedAt` so both share the same `MM:SS` anchor space.
    let offset: TimeInterval
    /// Optional human annotation. Empty when the user dropped a bare flag without typing.
    var text: String
    /// Wall-clock time the moment was captured.
    let createdAt: Date

    init(
        id: UUID = UUID(),
        offset: TimeInterval,
        text: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.offset = offset
        self.text = text
        self.createdAt = createdAt
    }

    /// `MM:SS` (or `H:MM:SS`) label for the moment's offset.
    var formattedTimestamp: String {
        TranscriptFormatter.timestampString(offset)
    }

    var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
