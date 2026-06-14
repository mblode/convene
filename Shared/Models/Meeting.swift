import Foundation

struct Meeting: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var attendees: [String]
    let startedAt: Date
    var endedAt: Date?
    var transcript: [TranscriptSegment]
    /// Live, human-marked flags dropped during the meeting (the differentiator). Optional in
    /// persisted JSON so legacy files without the key still decode.
    var keyMoments: [KeyMoment]
    var notes: String
    var summary: MeetingSummary?
    var transcriptionError: String?
    var audioFilename: String?
    /// Display name to use for `.you` transcript segments (e.g. the user's full name).
    var selfName: String?
    /// Display name to use for `.others` segments — only set for 1:1 meetings where the
    /// other participant is unambiguous.
    var othersName: String?

    init(
        id: UUID = UUID(),
        title: String = "Untitled meeting",
        attendees: [String] = [],
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        transcript: [TranscriptSegment] = [],
        keyMoments: [KeyMoment] = [],
        notes: String = "",
        summary: MeetingSummary? = nil,
        transcriptionError: String? = nil,
        audioFilename: String? = nil,
        selfName: String? = nil,
        othersName: String? = nil
    ) {
        self.id = id
        self.title = title
        self.attendees = attendees
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.transcript = transcript
        self.keyMoments = keyMoments
        self.notes = notes
        self.summary = summary
        self.transcriptionError = transcriptionError
        self.audioFilename = audioFilename
        self.selfName = selfName
        self.othersName = othersName
    }

    // Custom decode so legacy persisted JSON without `keyMoments` still loads. The encoder
    // stays synthesized.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        attendees = try container.decode([String].self, forKey: .attendees)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)
        transcript = try container.decode([TranscriptSegment].self, forKey: .transcript)
        keyMoments = try container.decodeIfPresent([KeyMoment].self, forKey: .keyMoments) ?? []
        notes = try container.decode(String.self, forKey: .notes)
        summary = try container.decodeIfPresent(MeetingSummary.self, forKey: .summary)
        transcriptionError = try container.decodeIfPresent(String.self, forKey: .transcriptionError)
        audioFilename = try container.decodeIfPresent(String.self, forKey: .audioFilename)
        selfName = try container.decodeIfPresent(String.self, forKey: .selfName)
        othersName = try container.decodeIfPresent(String.self, forKey: .othersName)
    }
}

/// One thematic/chronological section of the AI summary, with transcript citations.
struct SummaryDetail: Codable, Equatable {
    var title: String
    var narrative: String
    var timestamps: [String]

    init(title: String, narrative: String, timestamps: [String] = []) {
        self.title = title
        self.narrative = narrative
        self.timestamps = timestamps
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        narrative = try container.decode(String.self, forKey: .narrative)
        timestamps = try container.decodeIfPresent([String].self, forKey: .timestamps) ?? []
    }
}

struct MeetingSummary: Codable, Equatable {
    var overview: String
    var topics: [String]
    var keyPoints: [String]
    var details: [SummaryDetail]
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
        details: [SummaryDetail] = [],
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
        self.details = details
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
        details = try container.decodeIfPresent([SummaryDetail].self, forKey: .details) ?? []
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
