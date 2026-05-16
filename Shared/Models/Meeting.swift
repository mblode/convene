import Foundation

struct Meeting: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var attendees: [String]
    let startedAt: Date
    var endedAt: Date?
    var transcript: [TranscriptSegment]
    var notes: String
    var summary: MeetingSummary?
    var transcriptionError: String?
    var audioFilename: String?

    init(
        id: UUID = UUID(),
        title: String = "Untitled meeting",
        attendees: [String] = [],
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        transcript: [TranscriptSegment] = [],
        notes: String = "",
        summary: MeetingSummary? = nil,
        transcriptionError: String? = nil,
        audioFilename: String? = nil
    ) {
        self.id = id
        self.title = title
        self.attendees = attendees
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.transcript = transcript
        self.notes = notes
        self.summary = summary
        self.transcriptionError = transcriptionError
        self.audioFilename = audioFilename
    }
}

struct MeetingSummary: Codable, Equatable {
    var overview: String
    var keyPoints: [String]
    var actionItems: [String]
    var decisions: [String]
    var generatedAt: Date
}
