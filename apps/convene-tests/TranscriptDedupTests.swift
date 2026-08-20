import XCTest

@testable import Convene

final class TranscriptDedupTests: XCTestCase {

    // MARK: - Fixture

    /// Cross-stream duplicate pairs known to exist in meeting-4ec85721.json.
    /// Each phrase appears in exactly two raw segments — one .you (mic bleed)
    /// and one .others (system audio) — and must survive exactly once, as .others.
    private static let knownDuplicatePhrases = [
        "offline for like the last month",  // ~173s, the "Robin" pair
        "this notification and then hope",  // ~448s, "say"/"send this notification"
        "reason being that it's",  // ~820s, "cheap"/"shit for non-engineers" (Braze emails)
        "figure out what the content is",  // ~1207s, "back and forth" pair
        "this makes me happy"  // ~1863s, closing thanks
    ]

    private func loadFixtureMeeting() throws -> Meeting {
        try TestFixtures.meeting("meeting-4ec85721")
    }

    private func segments(containing phrase: String, in segments: [TranscriptSegment]) -> [TranscriptSegment]
    {
        segments.filter { $0.text.lowercased().contains(phrase.lowercased()) }
    }

    func testFixtureDecodesAsMeeting() throws {
        let meeting = try loadFixtureMeeting()
        XCTAssertEqual(meeting.transcript.count, 413)
        XCTAssertTrue(meeting.transcript.allSatisfy(\.isFinal))
    }

    func testFixtureDuplicatePairsCollapseToOthersCopy() throws {
        let meeting = try loadFixtureMeeting()
        let deduped = meeting.transcript.removingLikelyEchoDuplicates()

        XCTAssertLessThan(deduped.count, meeting.transcript.count)

        for phrase in Self.knownDuplicatePhrases {
            let raw = segments(containing: phrase, in: meeting.transcript)
            XCTAssertEqual(raw.count, 2, "Expected fixture to contain a duplicate pair for \"\(phrase)\"")
            XCTAssertEqual(
                Set(raw.map(\.speaker)), [.you, .others], "Expected one copy per stream for \"\(phrase)\"")

            let survivors = segments(containing: phrase, in: deduped)
            XCTAssertEqual(survivors.count, 1, "Expected \"\(phrase)\" to survive exactly once")
            XCTAssertEqual(
                survivors.first?.speaker, .others, "Expected the .others copy of \"\(phrase)\" to win")
        }
    }

    // MARK: - Dedup behavior

    func testLaterOthersCopyReplacesEarlierYouCopy() {
        let mic = makeSegment(
            .you, start: 100, end: 105,
            text: "moving away from braids for some all of our marketing emails")
        let system = makeSegment(
            .others, start: 103, end: 108,
            text: "moving away from Braze for some or all of our marketing emails")

        let deduped = [mic, system].removingLikelyEchoDuplicates()
        XCTAssertEqual(deduped.count, 1)
        XCTAssertEqual(deduped.first?.id, system.id)
        XCTAssertEqual(deduped.first?.speaker, .others)
    }

    func testEarlierOthersCopySuppressesLaterYouCopy() {
        let system = makeSegment(
            .others, start: 100, end: 105,
            text: "moving away from Braze for some or all of our marketing emails")
        let mic = makeSegment(
            .you, start: 103, end: 108,
            text: "moving away from braids for some all of our marketing emails")

        let deduped = [system, mic].removingLikelyEchoDuplicates()
        XCTAssertEqual(deduped.count, 1)
        XCTAssertEqual(deduped.first?.id, system.id)
    }

    func testShortAgreementsOnBothStreamsAreNotDeduped() {
        let input = [
            makeSegment(.you, start: 10.0, end: 10.5, text: "Yeah"),
            makeSegment(.others, start: 10.4, end: 11.0, text: "Yeah"),
            makeSegment(.you, start: 12.0, end: 12.8, text: "Okay cool cool"),
            makeSegment(.others, start: 12.3, end: 13.0, text: "Okay cool")
        ]
        XCTAssertEqual(input.removingLikelyEchoDuplicates().count, input.count)
    }

    func testSameSpeakerRepeatIsNotDeduped() {
        let line = "I really think we should ship the notification service next week"
        let input = [
            makeSegment(.you, start: 20, end: 24, text: line),
            makeSegment(.you, start: 25, end: 29, text: line)
        ]
        XCTAssertEqual(input.removingLikelyEchoDuplicates().count, 2)
    }

    func testDifferentLongSentencesWithinWindowAreNotDeduped() {
        let input = [
            makeSegment(
                .you, start: 30, end: 34,
                text: "I went to the supermarket yesterday evening to buy vegetables for dinner"),
            makeSegment(
                .others, start: 32, end: 36,
                text: "Our quarterly revenue numbers exceeded every forecast the finance team modelled")
        ]
        XCTAssertEqual(input.removingLikelyEchoDuplicates().count, 2)
    }

    // MARK: - Preference rule

    func testPreferredCopyPicksOthersForCrossStreamPair() {
        let mic = makeSegment(.you, start: 100, end: 104, text: "some shared sentence here")
        let system = makeSegment(.others, start: 102, end: 106, text: "some shared sentence here")

        XCTAssertEqual(TranscriptSegment.preferredCopy(mic, system).id, system.id)
        XCTAssertEqual(TranscriptSegment.preferredCopy(system, mic).id, system.id)
    }

    func testPreferredCopyPicksEarlierForSameKindPair() {
        let first = makeSegment(.you, start: 100, end: 104, text: "some shared sentence here")
        let second = makeSegment(.you, start: 102, end: 106, text: "some shared sentence here")

        XCTAssertEqual(TranscriptSegment.preferredCopy(first, second).id, first.id)
        XCTAssertEqual(TranscriptSegment.preferredCopy(second, first).id, first.id)
    }

    // MARK: - Fuzzy token matcher

    func testFuzzyTokenMatcherAcceptsAsrVariants() {
        // Same first four characters
        XCTAssertTrue(TranscriptSegment.echoTokensMatch("braids", "braize"))
        // Levenshtein distance 1
        XCTAssertTrue(TranscriptSegment.echoTokensMatch("braize", "braze"))
        XCTAssertTrue(TranscriptSegment.echoTokensMatch("emails", "email"))
        XCTAssertTrue(TranscriptSegment.echoTokensMatch("going", "doing"))
        // Exact match
        XCTAssertTrue(TranscriptSegment.echoTokensMatch("notification", "notification"))
        XCTAssertTrue(TranscriptSegment.echoTokensMatch("ok", "ok"))
    }

    func testFuzzyTokenMatcherRejectsDifferentTokens() {
        // Short tokens never fuzzy-match
        XCTAssertFalse(TranscriptSegment.echoTokensMatch("the", "they"))
        XCTAssertFalse(TranscriptSegment.echoTokensMatch("yeah", "yes"))
        // Unrelated long tokens
        XCTAssertFalse(TranscriptSegment.echoTokensMatch("yeah", "okay"))
        XCTAssertFalse(TranscriptSegment.echoTokensMatch("marketing", "engineering"))
    }

    func testCrossStreamAsrVariantsWithinWidenedWindowAreDeduped() {
        // Real-world style pair: same utterance, ~6s commit-clock drift between sessions.
        let mic = makeSegment(
            .you, start: 200.0, end: 204.0,
            text: "we are moving away from braids for all of our marketing emails")
        let system = makeSegment(
            .others, start: 206.0, end: 210.0,
            text: "we are moving away from Braze for all of our marketing emails")

        XCTAssertTrue(TranscriptSegment.isLikelyEchoDuplicate(system, of: mic))

        let deduped = [mic, system].removingLikelyEchoDuplicates()
        XCTAssertEqual(deduped.count, 1)
        XCTAssertEqual(deduped.first?.speaker, .others)
    }
}
