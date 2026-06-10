import XCTest
@testable import Convene

final class TranscriptFormatterTests: XCTestCase {
    private func segment(
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

    // MARK: - Merging

    func testMergesConsecutiveSameSpeakerSegmentsWithinGapThreshold() {
        let segments = [
            segment(.you, start: 0, end: 4, text: "Hello there."),
            segment(.you, start: 6, end: 10, text: "How are you?")
        ]
        let blocks = TranscriptFormatter.mergedBlocks(segments)
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].text, "Hello there. How are you?")
        XCTAssertEqual(blocks[0].startedAt, 0)
        XCTAssertEqual(blocks[0].endedAt, 10)
        XCTAssertFalse(blocks[0].isPartial)
    }

    func testGapBeyondThresholdStartsNewBlock() {
        let segments = [
            segment(.you, start: 0, end: 4, text: "First."),
            segment(.you, start: 14.5, end: 18, text: "Second.")
        ]
        let blocks = TranscriptFormatter.mergedBlocks(segments, gapThreshold: 10)
        XCTAssertEqual(blocks.count, 2)
        XCTAssertEqual(blocks[0].text, "First.")
        XCTAssertEqual(blocks[1].text, "Second.")
    }

    func testGapExactlyAtThresholdStillMerges() {
        let segments = [
            segment(.you, start: 0, end: 4, text: "First."),
            segment(.you, start: 14, end: 18, text: "Second.")
        ]
        let blocks = TranscriptFormatter.mergedBlocks(segments, gapThreshold: 10)
        XCTAssertEqual(blocks.count, 1)
    }

    func testSpeakerChangeSplitsBlocks() {
        let segments = [
            segment(.you, start: 0, end: 4, text: "Hi."),
            segment(.others, start: 4, end: 8, text: "Hey."),
            segment(.you, start: 8, end: 12, text: "Ready?")
        ]
        let blocks = TranscriptFormatter.mergedBlocks(segments)
        XCTAssertEqual(blocks.count, 3)
        XCTAssertEqual(blocks.map(\.speaker), [.you, .others, .you])
    }

    func testBlockIsPartialWhenAnyConstituentIsNonFinal() {
        let segments = [
            segment(.you, start: 0, end: 4, text: "Final part."),
            segment(.you, start: 5, end: 9, text: "Partial part", isFinal: false)
        ]
        let blocks = TranscriptFormatter.mergedBlocks(segments)
        XCTAssertEqual(blocks.count, 1)
        XCTAssertTrue(blocks[0].isPartial)
    }

    // MARK: - Sections

    func testSectionStartsWhenBlockBeginsIntervalAfterSectionStart() {
        let segments = [
            segment(.you, start: 0, end: 5, text: "A"),
            segment(.others, start: 60, end: 65, text: "B"),
            segment(.you, start: 76, end: 80, text: "C")
        ]
        let blocks = TranscriptFormatter.mergedBlocks(segments)
        let sections = TranscriptFormatter.sections(blocks, interval: 75)
        XCTAssertEqual(sections.count, 2)
        XCTAssertEqual(sections[0].startedAt, 0)
        XCTAssertEqual(sections[0].blocks.count, 2)
        XCTAssertEqual(sections[1].startedAt, 76)
        XCTAssertEqual(sections[1].blocks.count, 1)
    }

    func testSectionBoundaryIsRelativeToSectionStartNotPreviousBlock() {
        // Block at 100 is < 75s after the section start at 80, so it stays in that section
        // even though it is > 75s after the very first block.
        let blocks = TranscriptFormatter.mergedBlocks([
            segment(.you, start: 0, end: 5, text: "A"),
            segment(.others, start: 80, end: 85, text: "B"),
            segment(.you, start: 100, end: 105, text: "C")
        ])
        let sections = TranscriptFormatter.sections(blocks, interval: 75)
        XCTAssertEqual(sections.count, 2)
        XCTAssertEqual(sections[1].startedAt, 80)
        XCTAssertEqual(sections[1].blocks.count, 2)
    }

    func testSectionTimestampLookupIsDeterministic() {
        let blocks = TranscriptFormatter.mergedBlocks([
            segment(.you, start: 0, end: 5, text: "A"),
            segment(.others, start: 90, end: 95, text: "B"),
            segment(.you, start: 3700, end: 3705, text: "C")
        ])
        let sections = TranscriptFormatter.sections(blocks, interval: 75)
        XCTAssertEqual(TranscriptFormatter.sectionTimestamp(for: 0, in: sections), "00:00")
        XCTAssertEqual(TranscriptFormatter.sectionTimestamp(for: 50, in: sections), "00:00")
        XCTAssertEqual(TranscriptFormatter.sectionTimestamp(for: 92, in: sections), "01:30")
        XCTAssertEqual(TranscriptFormatter.sectionTimestamp(for: 3701, in: sections), "1:01:40")
        XCTAssertNil(TranscriptFormatter.sectionTimestamp(for: 10, in: []))
    }

    func testTimestampStringFormats() {
        XCTAssertEqual(TranscriptFormatter.timestampString(0), "00:00")
        XCTAssertEqual(TranscriptFormatter.timestampString(300), "05:00")
        XCTAssertEqual(TranscriptFormatter.timestampString(3661), "1:01:01")
    }

    // MARK: - Names

    func testDisplayNameFallbacks() {
        XCTAssertEqual(
            TranscriptFormatter.displayName(for: .you, selfName: nil, othersName: nil),
            "You"
        )
        XCTAssertEqual(
            TranscriptFormatter.displayName(for: .you, selfName: "Matthew Blode", othersName: nil),
            "Matthew Blode"
        )
        XCTAssertEqual(
            TranscriptFormatter.displayName(for: .others, selfName: nil, othersName: nil),
            "Others"
        )
        XCTAssertEqual(
            TranscriptFormatter.displayName(for: .others, selfName: nil, othersName: "Michael Ricci"),
            "Michael Ricci"
        )
        XCTAssertEqual(
            TranscriptFormatter.displayName(for: .named("Jane"), selfName: "X", othersName: "Y"),
            "Jane"
        )
    }

    // MARK: - Diarized speakers

    func testDisplayNameUsesDiarizedLabelForGroupMeetings() {
        XCTAssertEqual(
            TranscriptFormatter.displayName(for: .others, selfName: nil, othersName: nil, diarizedSpeaker: "A"),
            "Speaker A"
        )
        XCTAssertEqual(
            TranscriptFormatter.displayName(for: .others, selfName: "Matthew", othersName: nil, diarizedSpeaker: "B"),
            "Speaker B"
        )
    }

    func testDisplayNameOthersNameWinsOverDiarizedLabel() {
        XCTAssertEqual(
            TranscriptFormatter.displayName(for: .others, selfName: nil, othersName: "Michael", diarizedSpeaker: "A"),
            "Michael"
        )
    }

    func testDisplayNameNilDiarizedLabelFallsBackToOthers() {
        XCTAssertEqual(
            TranscriptFormatter.displayName(for: .others, selfName: nil, othersName: nil, diarizedSpeaker: nil),
            "Others"
        )
    }

    func testDisplayNameDiarizedLabelIgnoredForYou() {
        XCTAssertEqual(
            TranscriptFormatter.displayName(for: .you, selfName: nil, othersName: nil, diarizedSpeaker: "A"),
            "You"
        )
    }

    func testMergedBlocksSplitOnDiarizedSpeakerChange() {
        let segments = [
            segment(.others, start: 0, end: 4, text: "Hi all.", diarized: "A"),
            segment(.others, start: 5, end: 9, text: "Hello.", diarized: "B"),
            segment(.others, start: 10, end: 14, text: "Anyway.", diarized: "A")
        ]
        let blocks = TranscriptFormatter.mergedBlocks(segments)
        XCTAssertEqual(blocks.count, 3)
        XCTAssertEqual(blocks.map(\.diarizedSpeaker), ["A", "B", "A"])
    }

    func testMergedBlocksMergeSameDiarizedSpeaker() {
        let segments = [
            segment(.others, start: 0, end: 4, text: "Hi all.", diarized: "A"),
            segment(.others, start: 5, end: 9, text: "Good to see you.", diarized: "A")
        ]
        let blocks = TranscriptFormatter.mergedBlocks(segments)
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].text, "Hi all. Good to see you.")
        XCTAssertEqual(blocks[0].diarizedSpeaker, "A")
    }

    func testMergedBlocksTreatNilDiarizedSpeakersAsSame() {
        let segments = [
            segment(.others, start: 0, end: 4, text: "First."),
            segment(.others, start: 5, end: 9, text: "Second.")
        ]
        let blocks = TranscriptFormatter.mergedBlocks(segments)
        XCTAssertEqual(blocks.count, 1)
        XCTAssertNil(blocks[0].diarizedSpeaker)
    }

    func testMergedBlocksSplitWhenDiarizedSpeakerBecomesNil() {
        let segments = [
            segment(.others, start: 0, end: 4, text: "Labeled.", diarized: "A"),
            segment(.others, start: 5, end: 9, text: "Unlabeled.")
        ]
        let blocks = TranscriptFormatter.mergedBlocks(segments)
        XCTAssertEqual(blocks.count, 2)
        XCTAssertEqual(blocks[0].diarizedSpeaker, "A")
        XCTAssertNil(blocks[1].diarizedSpeaker)
    }

    func testAttendeeDisplayNameFromEmail() {
        XCTAssertEqual(TranscriptFormatter.attendeeDisplayName("michael@linktr.ee"), "Michael")
        XCTAssertEqual(TranscriptFormatter.attendeeDisplayName("jane.doe@example.com"), "Jane Doe")
        XCTAssertEqual(TranscriptFormatter.attendeeDisplayName("Matthew Blode"), "Matthew Blode")
        // A display name containing an @ but with spaces is kept as-is.
        XCTAssertEqual(TranscriptFormatter.attendeeDisplayName("Jane @ Work"), "Jane @ Work")
    }

    // MARK: - Meeting decode back-compat

    func testMeetingDecodesOldJSONWithoutSelfName() throws {
        let json = """
        {
            "id": "11111111-2222-3333-4444-555555555555",
            "title": "Old meeting",
            "attendees": [],
            "startedAt": "2026-01-05T10:00:00Z",
            "transcript": [],
            "notes": ""
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let meeting = try decoder.decode(Meeting.self, from: Data(json.utf8))
        XCTAssertEqual(meeting.title, "Old meeting")
        XCTAssertNil(meeting.selfName)
        XCTAssertNil(meeting.othersName)
    }
}
