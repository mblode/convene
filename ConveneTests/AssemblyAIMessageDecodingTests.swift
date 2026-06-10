import XCTest
@testable import Convene

final class AssemblyAIMessageDecodingTests: XCTestCase {

    private func fixtureData(_ name: String) throws -> Data {
        let url = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: name, withExtension: "json"),
            "Fixture \(name).json missing from test bundle"
        )
        return try Data(contentsOf: url)
    }

    private func decode(_ name: String) throws -> AssemblyAIServerMessage {
        try AssemblyAIServerMessage.decode(from: try fixtureData(name))
    }

    func testDecodesBeginMessage() throws {
        guard case .begin(let begin) = try decode("assemblyai-begin") else {
            return XCTFail("Expected .begin")
        }
        XCTAssertEqual(begin.id, "5c6e4d2a-8c00-4c3f-9a1e-1b2c3d4e5f60")
        XCTAssertEqual(begin.expiresAt, 1_749_542_400)
    }

    func testDecodesPartialTurn() throws {
        guard case .turn(let turn) = try decode("assemblyai-turn-partial") else {
            return XCTFail("Expected .turn")
        }
        XCTAssertEqual(turn.turnOrder, 2)
        XCTAssertFalse(turn.endOfTurn)
        XCTAssertEqual(turn.transcript, "so the plan for this quarter")
        XCTAssertNil(turn.speakerLabel)
        XCTAssertEqual(turn.words.count, 6)
        XCTAssertEqual(turn.words.first?.text, "so")
        XCTAssertEqual(turn.words.first?.start, 1200)
        XCTAssertEqual(turn.words.last?.wordIsFinal, false)
    }

    func testDecodesFinalTurnWithWordsAndSpeakerLabel() throws {
        guard case .turn(let turn) = try decode("assemblyai-turn-final") else {
            return XCTFail("Expected .turn")
        }
        XCTAssertEqual(turn.turnOrder, 2)
        XCTAssertTrue(turn.endOfTurn)
        XCTAssertEqual(turn.transcript, "So the plan for this quarter is to ship the redesign.")
        XCTAssertEqual(turn.speakerLabel, "B")
        XCTAssertEqual(turn.endOfTurnConfidence, 0.94)
        XCTAssertEqual(turn.words.count, 11)
        XCTAssertEqual(turn.words.first?.start, 1200)
        XCTAssertEqual(turn.words.last?.end, 3500)
        XCTAssertEqual(turn.words.last?.speaker, "B")
    }

    func testDecodesTurnWithUnknownSpeaker() throws {
        guard case .turn(let turn) = try decode("assemblyai-turn-unknown-speaker") else {
            return XCTFail("Expected .turn")
        }
        XCTAssertEqual(turn.turnOrder, 7)
        XCTAssertTrue(turn.endOfTurn)
        XCTAssertEqual(turn.speakerLabel, "UNKNOWN")
    }

    func testDecodesTermination() throws {
        guard case .termination(let termination) = try decode("assemblyai-termination") else {
            return XCTFail("Expected .termination")
        }
        XCTAssertEqual(termination.audioDurationSeconds, 1834.5)
        XCTAssertEqual(termination.sessionDurationSeconds, 1840.2)
    }

    func testDecodesSpeakerRevision() throws {
        guard case .speakerRevision(let revision) = try decode("assemblyai-speaker-revision") else {
            return XCTFail("Expected .speakerRevision")
        }
        XCTAssertEqual(revision.revisions, [2: "A", 7: "B"])
    }

    func testSpeakerRevisionToleratesUnexpectedShape() throws {
        let json = Data(#"{"type":"SpeakerRevision","something_else":{"weird":true}}"#.utf8)
        guard case .speakerRevision(let revision) = try AssemblyAIServerMessage.decode(from: json) else {
            return XCTFail("Expected .speakerRevision")
        }
        XCTAssertTrue(revision.revisions.isEmpty, "Unknown shapes decode to no revisions, not a throw")
    }

    func testUnknownMessageTypeIsToleratedSilently() throws {
        guard case .unknown(let type) = try decode("assemblyai-unknown-type") else {
            return XCTFail("Expected .unknown")
        }
        XCTAssertEqual(type, "SomeFutureMessage")
    }

    func testDecodesSpeechStarted() throws {
        let json = Data(#"{"type":"SpeechStarted","timestamp":12.5,"confidence":0.91}"#.utf8)
        guard case .speechStarted(let speech) = try AssemblyAIServerMessage.decode(from: json) else {
            return XCTFail("Expected .speechStarted")
        }
        XCTAssertEqual(speech.timestamp, 12.5)
        XCTAssertEqual(speech.confidence, 0.91)
    }
}
