import XCTest
@testable import Convene

final class LiveRecapTests: XCTestCase {
    private func segment(
        _ speaker: TranscriptSegment.Speaker,
        start: TimeInterval,
        end: TimeInterval,
        text: String
    ) -> TranscriptSegment {
        TranscriptSegment(speaker: speaker, startedAt: start, endedAt: end, text: text, isFinal: true)
    }

    private func transcript() -> [TranscriptSegment] {
        [
            segment(.you, start: 0, end: 10, text: "Early intro, well before the window."),
            segment(.others, start: 100, end: 110, text: "Middle discussion inside the window."),
            segment(.you, start: 200, end: 210, text: "Most recent exchange.")
        ]
    }

    func testTimelineKeepsOnlyTheTrailingWindow() {
        let items = LiveRecap.timeline(
            segments: transcript(),
            keyMoments: [KeyMoment(offset: 150, text: "Flag")],
            now: 210,
            window: 120
        )
        // cutoff = 90: drops the 0–10s block, keeps the 100s + 200s blocks and the 150s moment.
        XCTAssertEqual(items.count, 3)
        guard case .block(let first) = items[0] else { return XCTFail("expected block first") }
        XCTAssertEqual(first.text, "Middle discussion inside the window.")
        guard case .moment(let mid) = items[1] else { return XCTFail("expected moment second") }
        XCTAssertEqual(mid.text, "Flag")
        guard case .block = items[2] else { return XCTFail("expected block last") }
    }

    func testEmptyWindowReturnsNoItems() {
        let items = LiveRecap.timeline(
            segments: [segment(.you, start: 0, end: 10, text: "Old.")],
            keyMoments: [],
            now: 500,
            window: 120
        )
        XCTAssertTrue(items.isEmpty)
    }

    func testMomentSortsAheadOfBlockAtSameOffset() {
        let items = LiveRecap.timeline(
            segments: [segment(.others, start: 100, end: 110, text: "Block.")],
            keyMoments: [KeyMoment(offset: 100, text: "Marks what follows")],
            now: 150,
            window: 120
        )
        XCTAssertEqual(items.count, 2)
        guard case .moment = items[0] else { return XCTFail("moment should sort first at a tie") }
        guard case .block = items[1] else { return XCTFail("block should sort second at a tie") }
    }

    func testTranscriptTextIncludesOnlyWindowedBlocks() throws {
        let text = try XCTUnwrap(LiveRecap.transcriptText(segments: transcript(), now: 210, window: 120))
        XCTAssertTrue(text.contains("Middle discussion inside the window."))
        XCTAssertTrue(text.contains("Most recent exchange."))
        XCTAssertFalse(text.contains("Early intro"))
    }

    func testTranscriptTextNilWhenWindowEmpty() {
        let text = LiveRecap.transcriptText(
            segments: [segment(.you, start: 0, end: 10, text: "Old.")],
            now: 500,
            window: 120
        )
        XCTAssertNil(text)
    }
}
