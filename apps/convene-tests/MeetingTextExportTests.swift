import XCTest

@testable import Convene

final class MeetingTextExportTests: XCTestCase {
    func testTranscriptHasSpeakersTimestampsAndUnicodeWithoutMarkdown() {
        let meeting = makeMeeting(transcript: [
            makeSegment(.others, start: 4, end: 8, text: "Café ☕️", diarized: "A"),
            makeSegment(.others, start: 9, end: 10, text: "Next step", diarized: "B")
        ])
        XCTAssertEqual(
            MeetingTextExport.transcript(meeting), "Speaker A · 00:04\nCafé ☕️\n\nSpeaker B · 00:09\nNext step"
        )
    }

    func testBlankTranscriptExportsNothingAndPendingSpeakerIsHumanReadable() {
        XCTAssertEqual(
            MeetingTextExport.transcript(
                makeMeeting(transcript: [
                    makeSegment(.others, start: 0, end: 1, text: "  \n")
                ])), "")
        let meeting = makeMeeting(transcript: [
            makeSegment(.others, start: 0, end: 2, text: "Hello", diarized: "PENDING")
        ])
        XCTAssertEqual(MeetingTextExport.transcript(meeting), "Speaker · 00:00\nHello")
    }

    func testTextFileIncludesNotesAndTranscriptWithSafeUniqueURLs() throws {
        let meeting = makeMeeting(
            title: "Pricing / café?",
            transcript: [
                makeSegment(.you, start: 0, end: 2, text: "A useful transcript")
            ], notes: "Follow up tomorrow")
        let first = try PreparedTextExport(meeting: meeting)
        let second = try PreparedTextExport(meeting: meeting)
        defer {
            first.remove()
            second.remove()
        }
        XCTAssertEqual(first.url.pathExtension, "txt")
        XCTAssertNotEqual(first.url, second.url)
        let text = try String(contentsOf: first.url, encoding: .utf8)
        XCTAssertTrue(text.contains("Your notes\nFollow up tomorrow"))
        XCTAssertTrue(text.contains("Transcript\nYou · 00:00\nA useful transcript"))
        XCTAssertFalse(text.hasPrefix("---"))
        first.remove()
        first.remove()
        XCTAssertFalse(FileManager.default.fileExists(atPath: first.url.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: second.url.path))
    }

    func testFileCreationFailureIsReported() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("not a directory".utf8).write(to: directory)
        defer { try? FileManager.default.removeItem(at: directory) }
        XCTAssertThrowsError(try PreparedTextExport(meeting: makeMeeting(), temporaryDirectory: directory))
    }
}
