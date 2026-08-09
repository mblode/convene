import XCTest
@testable import Convene

final class TranscriptTurnAccumulatorTests: XCTestCase {

    private func turnMessage(
        order: Int,
        endOfTurn: Bool,
        transcript: String,
        speakerLabel: String? = nil,
        words: [AssemblyAIWord] = []
    ) -> AssemblyAITurnMessage {
        AssemblyAITurnMessage(
            turnOrder: order,
            endOfTurn: endOfTurn,
            transcript: transcript,
            endOfTurnConfidence: endOfTurn ? 0.9 : 0.1,
            speakerLabel: speakerLabel,
            words: words
        )
    }

    // MARK: - Partial → final

    func testPartialReplacesTextThenFinalizes() {
        var acc = TranscriptTurnAccumulator()

        XCTAssertNil(acc.handleTurn(turnMessage(order: 0, endOfTurn: false, transcript: "so the"), speaker: .you, currentElapsed: 0))
        XCTAssertEqual(acc.segments.count, 1)
        XCTAssertFalse(acc.segments[0].isFinal)

        // Partials carry the full turn text — replace, never append.
        XCTAssertNil(acc.handleTurn(turnMessage(order: 0, endOfTurn: false, transcript: "so the plan"), speaker: .you, currentElapsed: 0))
        XCTAssertEqual(acc.segments.count, 1)
        XCTAssertEqual(acc.segments[0].text, "so the plan")

        let confirmed = acc.handleTurn(turnMessage(order: 0, endOfTurn: true, transcript: "So the plan."), speaker: .you, currentElapsed: 0)
        XCTAssertEqual(acc.segments.count, 1)
        XCTAssertTrue(acc.segments[0].isFinal)
        XCTAssertEqual(confirmed?.text, "So the plan.")
    }

    func testEmptyFinalDropsAccumulatedPartial() {
        var acc = TranscriptTurnAccumulator()
        _ = acc.handleTurn(turnMessage(order: 0, endOfTurn: false, transcript: "half a thought"), speaker: .you, currentElapsed: 0)
        XCTAssertEqual(acc.segments.count, 1)

        let confirmed = acc.handleTurn(turnMessage(order: 0, endOfTurn: true, transcript: "   "), speaker: .you, currentElapsed: 0)
        XCTAssertNil(confirmed)
        XCTAssertTrue(acc.segments.isEmpty, "An empty final turn drops the partial it belonged to")
    }

    // MARK: - Cross-stream echo dedup

    private let echoPhrase = "We have been offline for like the last month working on this."

    func testEchoDuplicateOnMicIsDroppedKeepingOthersCopy() {
        var acc = TranscriptTurnAccumulator()
        let othersConfirmed = acc.handleTurn(
            turnMessage(order: 0, endOfTurn: true, transcript: echoPhrase,
                        words: [makeWord("We", start: 1000, end: 1100), makeWord("this.", start: 4000, end: 4400)]),
            speaker: .others, currentElapsed: 0
        )
        XCTAssertNotNil(othersConfirmed)

        let micConfirmed = acc.handleTurn(
            turnMessage(order: 0, endOfTurn: true, transcript: echoPhrase,
                        words: [makeWord("We", start: 1200, end: 1300), makeWord("this.", start: 4200, end: 4600)]),
            speaker: .you, currentElapsed: 0
        )
        XCTAssertNil(micConfirmed, "The mic echo must not be confirmed")
        XCTAssertEqual(acc.segments.count, 1)
        XCTAssertEqual(acc.segments.first?.speaker, .others)
    }

    func testEchoDuplicateOnOthersEvictsEarlierMicCopy() {
        var acc = TranscriptTurnAccumulator()
        _ = acc.handleTurn(
            turnMessage(order: 0, endOfTurn: true, transcript: echoPhrase,
                        words: [makeWord("We", start: 1000, end: 1100), makeWord("this.", start: 4000, end: 4400)]),
            speaker: .you, currentElapsed: 0
        )
        let othersConfirmed = acc.handleTurn(
            turnMessage(order: 0, endOfTurn: true, transcript: echoPhrase,
                        words: [makeWord("We", start: 1200, end: 1300), makeWord("this.", start: 4200, end: 4600)]),
            speaker: .others, currentElapsed: 0
        )
        XCTAssertNotNil(othersConfirmed, "The .others copy wins and is confirmed")
        XCTAssertEqual(acc.segments.count, 1)
        XCTAssertEqual(acc.segments.first?.speaker, .others)
    }

    // MARK: - Speaker revision

    func testSpeakerRevisionRelabelsKnownTurnAndIgnoresUnknown() {
        var acc = TranscriptTurnAccumulator()
        _ = acc.handleTurn(turnMessage(order: 0, endOfTurn: true, transcript: "First.", speakerLabel: "A"), speaker: .others, currentElapsed: 0)

        // Turn 0 is known; turn 42 was never seen and must be ignored without crashing.
        acc.applySpeakerRevision(AssemblyAISpeakerRevisionMessage(revisions: [0: "B", 42: "C"]), speaker: .others)
        XCTAssertEqual(acc.segments.count, 1)
        XCTAssertEqual(acc.segments[0].diarizedSpeaker, "B")
    }

    func testResetClearsSegments() {
        var acc = TranscriptTurnAccumulator()
        _ = acc.handleTurn(turnMessage(order: 0, endOfTurn: true, transcript: "Something."), speaker: .you, currentElapsed: 0)
        XCTAssertFalse(acc.segments.isEmpty)
        acc.reset()
        XCTAssertTrue(acc.segments.isEmpty)
    }
}
