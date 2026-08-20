import Foundation
import XCTest

@testable import Convene

// Shared factories and fixture loaders for the test target, replacing the per-file copies that
// had drifted in signature.

/// Anchors `Bundle(for:)` to the test bundle so fixture files resolve from any test.
private final class TestBundleToken {}

func makeSegment(
    _ speaker: TranscriptSegment.Speaker,
    start: TimeInterval,
    end: TimeInterval,
    text: String,
    isFinal: Bool = true,
    diarized: String? = nil
) -> TranscriptSegment {
    var segment = TranscriptSegment(
        speaker: speaker,
        startedAt: start,
        endedAt: end,
        text: text,
        isFinal: isFinal
    )
    segment.diarizedSpeaker = diarized
    return segment
}

func makeMeeting(
    id: UUID = UUID(),
    title: String = "Test meeting",
    attendees: [String] = [],
    startedAt: Date = Date(timeIntervalSince1970: 1_750_000_000),
    endedAt: Date? = Date(timeIntervalSince1970: 1_750_001_800),
    transcript: [TranscriptSegment] = [],
    keyMoments: [KeyMoment] = [],
    notes: String = "",
    summary: MeetingSummary? = nil,
    transcriptionError: String? = nil,
    selfName: String? = nil,
    othersName: String? = nil
) -> Meeting {
    Meeting(
        id: id,
        title: title,
        attendees: attendees,
        startedAt: startedAt,
        endedAt: endedAt,
        transcript: transcript,
        keyMoments: keyMoments,
        notes: notes,
        summary: summary,
        transcriptionError: transcriptionError,
        selfName: selfName,
        othersName: othersName
    )
}

func makeWord(_ text: String, start: Int, end: Int, speaker: String? = nil) -> AssemblyAIWord {
    AssemblyAIWord(
        text: text,
        start: start,
        end: end,
        confidence: 0.95,
        wordIsFinal: true,
        speaker: speaker
    )
}

func makeTurn(
    order: Int,
    endOfTurn: Bool,
    transcript: String,
    speakerLabel: String? = nil,
    words: [AssemblyAIWord] = []
) -> AssemblyAIServerMessage {
    .turn(
        AssemblyAITurnMessage(
            turnOrder: order,
            endOfTurn: endOfTurn,
            transcript: transcript,
            endOfTurnConfidence: endOfTurn ? 0.9 : 0.1,
            speakerLabel: speakerLabel,
            words: words
        ))
}

enum TestFixtures {
    /// Raw bytes of a JSON fixture in the test bundle (without the `.json` extension).
    static func data(_ name: String) throws -> Data {
        let url = try XCTUnwrap(
            Bundle(for: TestBundleToken.self).url(forResource: name, withExtension: "json"),
            "Missing fixture \(name).json"
        )
        return try Data(contentsOf: url)
    }

    /// Decodes a persisted meeting fixture (ISO-8601 dates, as written on disk).
    static func meeting(_ name: String) throws -> Meeting {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Meeting.self, from: data(name))
    }
}
