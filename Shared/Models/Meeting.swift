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
    var topics: [String]
    var keyPoints: [String]
    var actionItems: [String]
    var decisions: [String]
    var openQuestions: [String]
    var followUps: [String]
    var generatedAt: Date
    var provider: String?
    var model: String?
    var promptVersion: String?

    init(
        overview: String,
        topics: [String] = [],
        keyPoints: [String],
        actionItems: [String],
        decisions: [String],
        openQuestions: [String] = [],
        followUps: [String] = [],
        generatedAt: Date,
        provider: String? = nil,
        model: String? = nil,
        promptVersion: String? = nil
    ) {
        self.overview = overview
        self.topics = topics
        self.keyPoints = keyPoints
        self.actionItems = actionItems
        self.decisions = decisions
        self.openQuestions = openQuestions
        self.followUps = followUps
        self.generatedAt = generatedAt
        self.provider = provider
        self.model = model
        self.promptVersion = promptVersion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        overview = try container.decode(String.self, forKey: .overview)
        topics = try container.decodeIfPresent([String].self, forKey: .topics) ?? []
        keyPoints = try container.decodeIfPresent([String].self, forKey: .keyPoints) ?? []
        actionItems = try container.decodeIfPresent([String].self, forKey: .actionItems) ?? []
        decisions = try container.decodeIfPresent([String].self, forKey: .decisions) ?? []
        openQuestions = try container.decodeIfPresent([String].self, forKey: .openQuestions) ?? []
        followUps = try container.decodeIfPresent([String].self, forKey: .followUps) ?? []
        generatedAt = try container.decode(Date.self, forKey: .generatedAt)
        provider = try container.decodeIfPresent(String.self, forKey: .provider)
        model = try container.decodeIfPresent(String.self, forKey: .model)
        promptVersion = try container.decodeIfPresent(String.self, forKey: .promptVersion)
    }
}
