import XCTest
@testable import Convene

@MainActor
final class AssemblyAITurnMappingTests: XCTestCase {

    private func makeTranscriber() -> AssemblyAIRealtimeTranscriber {
        AssemblyAIRealtimeTranscriber()
    }

    // MARK: - Partial → final replacement

    func testPartialGrowsThenFinalizesByReplacingText() {
        let transcriber = makeTranscriber()

        transcriber.handleServerMessage(
            makeTurn(order: 0, endOfTurn: false, transcript: "so the plan",
                 words: [makeWord("so", start: 1000, end: 1100)]),
            for: .you
        )
        XCTAssertEqual(transcriber.segments.count, 1)
        XCTAssertEqual(transcriber.segments[0].text, "so the plan")
        XCTAssertFalse(transcriber.segments[0].isFinal)

        // Partials carry the FULL turn text so far — text must be replaced, not appended.
        transcriber.handleServerMessage(
            makeTurn(order: 0, endOfTurn: false, transcript: "so the plan for this quarter",
                 words: [makeWord("so", start: 1000, end: 1100), makeWord("quarter", start: 2000, end: 2400)]),
            for: .you
        )
        XCTAssertEqual(transcriber.segments.count, 1)
        XCTAssertEqual(transcriber.segments[0].text, "so the plan for this quarter")

        transcriber.handleServerMessage(
            makeTurn(order: 0, endOfTurn: true, transcript: "So the plan for this quarter is set.",
                 words: [makeWord("So", start: 1000, end: 1100), makeWord("set.", start: 3000, end: 3400)]),
            for: .you
        )
        XCTAssertEqual(transcriber.segments.count, 1)
        XCTAssertEqual(transcriber.segments[0].text, "So the plan for this quarter is set.")
        XCTAssertTrue(transcriber.segments[0].isFinal)
    }

    func testFinalizedSegmentIsConfirmed() {
        let transcriber = makeTranscriber()
        var confirmed: [TranscriptSegment] = []
        transcriber.onSegmentConfirmed = { confirmed.append($0) }

        transcriber.handleServerMessage(
            makeTurn(order: 0, endOfTurn: false, transcript: "hello there"),
            for: .you
        )
        XCTAssertTrue(confirmed.isEmpty, "Partials must not be confirmed")

        transcriber.handleServerMessage(
            makeTurn(order: 0, endOfTurn: true, transcript: "Hello there."),
            for: .you
        )
        XCTAssertEqual(confirmed.map(\.text), ["Hello there."])
    }

    // MARK: - Turn-order keying

    func testTurnsAreKeyedByTurnOrderPerStream() {
        let transcriber = makeTranscriber()

        transcriber.handleServerMessage(makeTurn(order: 0, endOfTurn: false, transcript: "first turn"), for: .you)
        transcriber.handleServerMessage(makeTurn(order: 1, endOfTurn: false, transcript: "second turn"), for: .you)
        // Same turn_order on the other stream is a distinct segment.
        transcriber.handleServerMessage(makeTurn(order: 0, endOfTurn: false, transcript: "their first turn"), for: .others)

        XCTAssertEqual(transcriber.segments.count, 3)
        XCTAssertEqual(transcriber.segments.map(\.text), ["first turn", "second turn", "their first turn"])

        // Updating you:0 only touches the matching segment.
        transcriber.handleServerMessage(makeTurn(order: 0, endOfTurn: false, transcript: "first turn updated"), for: .you)
        XCTAssertEqual(transcriber.segments.map(\.text), ["first turn updated", "second turn", "their first turn"])
    }

    // MARK: - Word-based timestamps

    func testTimestampsDeriveFromWordTimes() {
        let transcriber = makeTranscriber()
        transcriber.handleServerMessage(
            makeTurn(order: 0, endOfTurn: true, transcript: "Timed words here.",
                 words: [makeWord("Timed", start: 1500, end: 1900), makeWord("here.", start: 4200, end: 4750)]),
            for: .you
        )
        // No Begin processed → connectElapsed is 0, so times are word times in seconds.
        XCTAssertEqual(transcriber.segments.first?.startedAt ?? -1, 1.5, accuracy: 0.001)
        XCTAssertEqual(transcriber.segments.first?.endedAt ?? -1, 4.75, accuracy: 0.001)
    }

    // MARK: - Diarization

    func testDiarizedSpeakerIsSetFromSpeakerLabel() {
        let transcriber = makeTranscriber()
        transcriber.handleServerMessage(
            makeTurn(order: 0, endOfTurn: true, transcript: "Speaker labelled text.", speakerLabel: "B"),
            for: .others
        )
        XCTAssertEqual(transcriber.segments.first?.diarizedSpeaker, "B")
    }

    func testUnknownSpeakerLabelMapsToNil() {
        let transcriber = makeTranscriber()
        transcriber.handleServerMessage(
            makeTurn(order: 0, endOfTurn: true, transcript: "Unattributed speech here.", speakerLabel: "UNKNOWN"),
            for: .others
        )
        XCTAssertEqual(transcriber.segments.count, 1)
        XCTAssertNil(transcriber.segments.first?.diarizedSpeaker)
    }

    func testSpeakerRevisionRelabelsTurns() {
        let transcriber = makeTranscriber()
        transcriber.handleServerMessage(
            makeTurn(order: 0, endOfTurn: true, transcript: "First speaker remarks.", speakerLabel: "A"),
            for: .others
        )
        transcriber.handleServerMessage(
            makeTurn(order: 1, endOfTurn: true, transcript: "Second speaker replies.", speakerLabel: "A"),
            for: .others
        )

        transcriber.handleServerMessage(
            .speakerRevision(AssemblyAISpeakerRevisionMessage(revisions: [1: "B", 99: "C"])),
            for: .others
        )

        XCTAssertEqual(transcriber.segments[0].diarizedSpeaker, "A")
        XCTAssertEqual(transcriber.segments[1].diarizedSpeaker, "B")
    }

    func testSpeakerRevisionToUnknownClearsLabel() {
        let transcriber = makeTranscriber()
        transcriber.handleServerMessage(
            makeTurn(order: 0, endOfTurn: true, transcript: "Some labelled remarks here.", speakerLabel: "A"),
            for: .others
        )
        transcriber.handleServerMessage(
            .speakerRevision(AssemblyAISpeakerRevisionMessage(revisions: [0: "UNKNOWN"])),
            for: .others
        )
        XCTAssertNil(transcriber.segments[0].diarizedSpeaker)
    }

    // MARK: - Cross-stream echo dedup

    func testEchoDuplicateOnMicIsSuppressedKeepingOthersCopy() {
        let transcriber = makeTranscriber()
        let phrase = "We have been offline for like the last month working on this."

        transcriber.handleServerMessage(
            makeTurn(order: 0, endOfTurn: true, transcript: phrase,
                 words: [makeWord("We", start: 1000, end: 1100), makeWord("this.", start: 4000, end: 4400)]),
            for: .others
        )
        var confirmedTexts: [String] = []
        transcriber.onSegmentConfirmed = { confirmedTexts.append($0.text) }
        transcriber.handleServerMessage(
            makeTurn(order: 0, endOfTurn: true, transcript: phrase,
                 words: [makeWord("We", start: 1200, end: 1300), makeWord("this.", start: 4200, end: 4600)]),
            for: .you
        )

        XCTAssertEqual(transcriber.segments.count, 1, "Mic echo of system audio must collapse to one segment")
        XCTAssertEqual(transcriber.segments.first?.speaker, .others, ".others copy wins a cross-stream pair")
        XCTAssertTrue(confirmedTexts.isEmpty, "Suppressed duplicate must not be confirmed")
    }

    func testEchoDuplicateOnSystemStreamEvictsEarlierMicCopy() {
        let transcriber = makeTranscriber()
        let phrase = "We have been offline for like the last month working on this."

        transcriber.handleServerMessage(
            makeTurn(order: 0, endOfTurn: true, transcript: phrase,
                 words: [makeWord("We", start: 1000, end: 1100), makeWord("this.", start: 4000, end: 4400)]),
            for: .you
        )
        transcriber.handleServerMessage(
            makeTurn(order: 0, endOfTurn: true, transcript: phrase,
                 words: [makeWord("We", start: 1200, end: 1300), makeWord("this.", start: 4200, end: 4600)]),
            for: .others
        )

        XCTAssertEqual(transcriber.segments.count, 1)
        XCTAssertEqual(transcriber.segments.first?.speaker, .others, ".others copy replaces the earlier .you copy")
    }

    func testDistinctSentencesOnBothStreamsAreKept() {
        let transcriber = makeTranscriber()
        transcriber.handleServerMessage(
            makeTurn(order: 0, endOfTurn: true, transcript: "Let me share my screen with everyone now.",
                 words: [makeWord("Let", start: 1000, end: 1100)]),
            for: .you
        )
        transcriber.handleServerMessage(
            makeTurn(order: 0, endOfTurn: true, transcript: "The quarterly numbers look very strong indeed.",
                 words: [makeWord("The", start: 1500, end: 1600)]),
            for: .others
        )
        XCTAssertEqual(transcriber.segments.count, 2)
    }

    // MARK: - Legacy persistence

    func testLegacySegmentJSONWithoutDiarizedSpeakerDecodes() throws {
        let legacy = Data("""
        {
            "id": "9C7E1F7E-2C2B-4B7B-9A8B-1234567890AB",
            "speaker": "others",
            "startedAt": 12.5,
            "endedAt": 18.25,
            "text": "Legacy segment without diarization.",
            "isFinal": true
        }
        """.utf8)
        let segment = try JSONDecoder().decode(TranscriptSegment.self, from: legacy)
        XCTAssertEqual(segment.text, "Legacy segment without diarization.")
        XCTAssertEqual(segment.speaker, .others)
        XCTAssertNil(segment.diarizedSpeaker)
    }

    func testSegmentRoundTripsDiarizedSpeaker() throws {
        let segment = TranscriptSegment(
            speaker: .others,
            startedAt: 1,
            endedAt: 2,
            text: "Round trip with label.",
            isFinal: true,
            diarizedSpeaker: "B"
        )
        let data = try JSONEncoder().encode(segment)
        let decoded = try JSONDecoder().decode(TranscriptSegment.self, from: data)
        XCTAssertEqual(decoded.diarizedSpeaker, "B")
    }
}
