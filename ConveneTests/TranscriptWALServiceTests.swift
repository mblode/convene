import XCTest
@testable import Convene

final class TranscriptWALServiceTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("convene-wal-tests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testRecoversOrphanedWALWithTranscriptAndKeyMoments() throws {
        let start = Date(timeIntervalSince1970: 1_750_000_000)
        let id = UUID()

        let writer = TranscriptWALService(directory: tempDir)
        writer.beginSession(meetingId: id, title: "Standup", attendees: ["a@x.com"], startedAt: start)
        writer.appendSegment(makeSegment(.you, start: 1, end: 3, text: "Hello"))
        writer.appendKeyMoment(KeyMoment(offset: 2, text: "flag"))
        // endSession flushes the async writes and closes the handle, but leaves the file on disk —
        // exactly the orphan state a crash-before-cleanup would leave.
        let url = try XCTUnwrap(writer.endSession())

        let reader = TranscriptWALService(directory: tempDir)
        // Compare by filename: contentsOfDirectory resolves the /private symlink on macOS.
        XCTAssertEqual(reader.findOrphanedWALs().map(\.lastPathComponent), [url.lastPathComponent])

        let meeting = try TranscriptWALService.recoverMeeting(from: url)
        XCTAssertEqual(meeting.id, id)
        XCTAssertEqual(meeting.title, "[Recovered] Standup")
        XCTAssertEqual(meeting.attendees, ["a@x.com"])
        XCTAssertEqual(meeting.transcript.map(\.text), ["Hello"])
        XCTAssertEqual(meeting.keyMoments.map(\.text), ["flag"])
        // endedAt derives from the last offset: max(segment end 3, moment offset 2) = 3.
        XCTAssertEqual(meeting.endedAt, start.addingTimeInterval(3))

        TranscriptWALService.deleteWAL(at: url)
        XCTAssertTrue(reader.findOrphanedWALs().isEmpty)
    }

    func testRecoveryToleratesCorruptTrailingLine() throws {
        let start = Date(timeIntervalSince1970: 1_750_000_000)
        let writer = TranscriptWALService(directory: tempDir)
        writer.beginSession(meetingId: UUID(), title: "Notes", attendees: [], startedAt: start)
        writer.appendSegment(makeSegment(.you, start: 1, end: 2, text: "Good line"))
        let url = try XCTUnwrap(writer.endSession())

        // Simulate a half-written trailing line from a crash mid-append.
        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        handle.write(Data("{ not valid json".utf8))
        try handle.close()

        let meeting = try TranscriptWALService.recoverMeeting(from: url)
        XCTAssertEqual(meeting.transcript.map(\.text), ["Good line"], "Valid lines survive a corrupt trailing line")
    }

    func testRecoverMeetingThrowsOnEmptyFile() throws {
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let url = tempDir.appendingPathComponent("empty.wal.jsonl")
        FileManager.default.createFile(atPath: url.path, contents: Data())
        XCTAssertThrowsError(try TranscriptWALService.recoverMeeting(from: url))
    }
}
