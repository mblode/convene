import XCTest

@testable import Convene

@MainActor
final class RecordingRecoveryTests: XCTestCase {
    func testFailedRecoveryKeepsJournalUntilRetrySucceeds() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let wal = TranscriptWALService(directory: directory)
        let id = UUID()
        wal.beginSession(meetingId: id, title: "Recovery test", attendees: [], startedAt: Date())
        wal.appendSegment(makeSegment(.others, start: 0, end: 3, text: "Keep this", diarized: "A"))
        let file = try XCTUnwrap(wal.endSession())
        let persistence = RecoveryPersistence()
        let session = makeSession(persistence: persistence, wal: wal)
        session.recoverOrphanedMeetings()
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        XCTAssertEqual(persistence.meetings.first?.id, id)
        XCTAssertEqual(persistence.meetings.first?.transcript.first?.diarizedSpeaker, "A")
        XCTAssertFalse(persistence.meetings.first?.transcriptionError?.contains("crash") ?? true)
        persistence.shouldSucceed = true
        session.retryPendingSave()
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        session.recoverOrphanedMeetings()
        XCTAssertEqual(persistence.meetings.count, 2, "A successful retry is not recovered again")
    }

    func testNotesOnlyRecoveryIsSaved() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let wal = TranscriptWALService(directory: directory)
        wal.beginSession(meetingId: UUID(), title: "Notes", attendees: [], startedAt: Date())
        wal.appendMetadata(title: "Edited title", notes: "Important typed notes")
        let file = try XCTUnwrap(wal.endSession())
        let persistence = RecoveryPersistence()
        persistence.shouldSucceed = true
        makeSession(persistence: persistence, wal: wal).recoverOrphanedMeetings()
        XCTAssertEqual(persistence.meetings.first?.notes, "Important typed notes")
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    private func makeSession(persistence: RecoveryPersistence, wal: TranscriptWALService) -> RecordingSession
    {
        RecordingSession(
            audioSource: RecoveryAudioSource(), persistence: persistence, makeContext: { .empty },
            meetingMetadata: { ("", "") }, transcriptionKey: { "" }, shouldSummarize: { false },
            summarize: { _ in nil }, summaryError: { nil }, walService: wal
        )
    }
}

@MainActor
private final class RecoveryPersistence: MeetingPersisting {
    var shouldSucceed = false
    var meetings: [Meeting] = []
    var lastError: String? { shouldSucceed ? nil : "Test write failure" }
    var lastUsedFallback = false
    func save(_ meeting: Meeting) -> URL? {
        meetings.append(meeting)
        return shouldSucceed ? URL(fileURLWithPath: "/tmp/recovery-test.md") : nil
    }
}

@MainActor
private final class RecoveryAudioSource: RecordingAudioSource {
    var isCapturing = false
    var permissionFailureMessage: String? { nil }
    func requestPermissions() async -> Bool { true }
    func start(onPCM16: @escaping (TranscriptSegment.Speaker, Data) -> Void) async throws {}
    func stop() async {}
}
