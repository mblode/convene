import Foundation

// Codable models for AssemblyAI Universal-Streaming (v3) server messages.
// Pure data + decoding — no networking — so message handling is unit-testable.

/// `Begin` — session opened; audio may now flow.
struct AssemblyAIBeginMessage: Codable, Equatable {
    let id: String
    let expiresAt: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case expiresAt = "expires_at"
    }
}

/// One word within a `Turn` message. Times are milliseconds from session start.
struct AssemblyAIWord: Codable, Equatable {
    let text: String
    let start: Int
    let end: Int
    let confidence: Double?
    let wordIsFinal: Bool?
    let speaker: String?

    enum CodingKeys: String, CodingKey {
        case text
        case start
        case end
        case confidence
        case wordIsFinal = "word_is_final"
        case speaker
    }
}

/// `Turn` — partial (`end_of_turn == false`, transcript carries the FULL turn text so
/// far → replace, never append) or finalized + formatted (`end_of_turn == true`).
struct AssemblyAITurnMessage: Codable, Equatable {
    let turnOrder: Int
    let endOfTurn: Bool
    let transcript: String
    let endOfTurnConfidence: Double?
    let speakerLabel: String?
    let words: [AssemblyAIWord]

    enum CodingKeys: String, CodingKey {
        case turnOrder = "turn_order"
        case endOfTurn = "end_of_turn"
        case transcript
        case endOfTurnConfidence = "end_of_turn_confidence"
        case speakerLabel = "speaker_label"
        case words
    }

    init(
        turnOrder: Int,
        endOfTurn: Bool,
        transcript: String,
        endOfTurnConfidence: Double? = nil,
        speakerLabel: String? = nil,
        words: [AssemblyAIWord] = []
    ) {
        self.turnOrder = turnOrder
        self.endOfTurn = endOfTurn
        self.transcript = transcript
        self.endOfTurnConfidence = endOfTurnConfidence
        self.speakerLabel = speakerLabel
        self.words = words
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        turnOrder = try container.decode(Int.self, forKey: .turnOrder)
        endOfTurn = try container.decode(Bool.self, forKey: .endOfTurn)
        transcript = try container.decodeIfPresent(String.self, forKey: .transcript) ?? ""
        endOfTurnConfidence = try container.decodeIfPresent(Double.self, forKey: .endOfTurnConfidence)
        speakerLabel = try container.decodeIfPresent(String.self, forKey: .speakerLabel)
        words = try container.decodeIfPresent([AssemblyAIWord].self, forKey: .words) ?? []
    }
}

/// `Termination` — session closed after a client `Terminate`.
struct AssemblyAITerminationMessage: Codable, Equatable {
    let audioDurationSeconds: Double?
    let sessionDurationSeconds: Double?

    enum CodingKeys: String, CodingKey {
        case audioDurationSeconds = "audio_duration_seconds"
        case sessionDurationSeconds = "session_duration_seconds"
    }
}

/// `SpeakerRevision` — refined diarization labels for changed turns, sent after
/// `Terminate`. Decoded defensively: the payload is expected to carry
/// turn_order → speaker_label pairs, so we accept both an array of
/// `{turn_order, speaker_label}` objects (under `turns` or `revisions`) and a flat
/// `{"<turn_order>": "<label>"}` dictionary, ignoring anything else.
struct AssemblyAISpeakerRevisionMessage: Codable, Equatable {
    /// turn_order → revised speaker label.
    let revisions: [Int: String]

    init(revisions: [Int: String]) {
        self.revisions = revisions
    }

    private struct RevisionPair: Codable {
        let turnOrder: Int
        let speakerLabel: String

        enum CodingKeys: String, CodingKey {
            case turnOrder = "turn_order"
            case speakerLabel = "speaker_label"
        }
    }

    private enum ContainerKeys: String, CodingKey {
        case turns
        case revisions
        case speakerLabels = "speaker_labels"
    }

    init(from decoder: Decoder) throws {
        var collected: [Int: String] = [:]

        if let container = try? decoder.container(keyedBy: ContainerKeys.self) {
            for key in [ContainerKeys.turns, .revisions] {
                if let pairs = try? container.decodeIfPresent([RevisionPair].self, forKey: key) {
                    for pair in pairs {
                        collected[pair.turnOrder] = pair.speakerLabel
                    }
                }
            }
            if collected.isEmpty,
               let map = try? container.decodeIfPresent([String: String].self, forKey: .speakerLabels) {
                for (key, label) in map {
                    if let order = Int(key) {
                        collected[order] = label
                    }
                }
            }
        }

        revisions = collected
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: ContainerKeys.self)
        let pairs = revisions
            .sorted { $0.key < $1.key }
            .map { RevisionPair(turnOrder: $0.key, speakerLabel: $0.value) }
        try container.encode(pairs, forKey: .turns)
    }
}

/// `SpeechStarted` — voice activity detected.
struct AssemblyAISpeechStartedMessage: Codable, Equatable {
    let timestamp: Double?
    let confidence: Double?
}

/// Envelope over every server message, keyed on the `type` field. Unknown types are
/// surfaced as `.unknown` so callers can ignore them silently.
enum AssemblyAIServerMessage: Equatable {
    case begin(AssemblyAIBeginMessage)
    case turn(AssemblyAITurnMessage)
    case termination(AssemblyAITerminationMessage)
    case speakerRevision(AssemblyAISpeakerRevisionMessage)
    case speechStarted(AssemblyAISpeechStartedMessage)
    case unknown(type: String)

    private struct TypeProbe: Codable {
        let type: String
    }

    static func decode(from data: Data) throws -> AssemblyAIServerMessage {
        let decoder = JSONDecoder()
        let probe = try decoder.decode(TypeProbe.self, from: data)
        switch probe.type {
        case "Begin":
            return .begin(try decoder.decode(AssemblyAIBeginMessage.self, from: data))
        case "Turn":
            return .turn(try decoder.decode(AssemblyAITurnMessage.self, from: data))
        case "Termination":
            return .termination(try decoder.decode(AssemblyAITerminationMessage.self, from: data))
        case "SpeakerRevision":
            return .speakerRevision(try decoder.decode(AssemblyAISpeakerRevisionMessage.self, from: data))
        case "SpeechStarted":
            return .speechStarted(try decoder.decode(AssemblyAISpeechStartedMessage.self, from: data))
        default:
            return .unknown(type: probe.type)
        }
    }
}

/// Client → server control messages.
enum AssemblyAIClientMessage {
    case terminate
    case forceEndpoint

    var jsonData: Data {
        switch self {
        case .terminate:
            return Data(#"{"type":"Terminate"}"#.utf8)
        case .forceEndpoint:
            return Data(#"{"type":"ForceEndpoint"}"#.utf8)
        }
    }
}
