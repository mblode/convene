import UIKit
import UniformTypeIdentifiers
import XCTest

@testable import Convene

@MainActor
final class MeetingExportControllerTests: XCTestCase {
    func testMarkdownCopyWritesActualUTF8TextAndConfirmsEveryTap() {
        let pasteboard = UIPasteboard.withUniqueName()
        defer { UIPasteboard.remove(withName: pasteboard.name) }
        let controller = MeetingExportController(pasteboard: pasteboard)
        var meeting = Meeting(title: "Recovered meeting", notes: "Café ☕️")
        controller.copyMarkdown(meeting)
        XCTAssertEqual(pasteboard.string, MarkdownRenderer.renderMarkdown(meeting))
        XCTAssertEqual(controller.feedback, "Markdown copied")
        XCTAssertTrue(pasteboard.contains(pasteboardTypes: [UTType.utf8PlainText.identifier]))
        meeting.notes = "An updated note"
        controller.copyMarkdown(meeting)
        XCTAssertEqual(pasteboard.string, MarkdownRenderer.renderMarkdown(meeting))
        XCTAssertEqual(controller.feedback, "Markdown copied")
    }

    func testTranscriptCopyHasNoMarkdownAndEmptyCopyKeepsClipboard() {
        let pasteboard = UIPasteboard.withUniqueName()
        defer { UIPasteboard.remove(withName: pasteboard.name) }
        let controller = MeetingExportController(pasteboard: pasteboard)
        let meeting = Meeting(transcript: [
            TranscriptSegment(
                speaker: .others, startedAt: 4, endedAt: 8, text: "Hello", isFinal: true, diarizedSpeaker: "A"
            )
        ])
        controller.copyTranscript(meeting)
        XCTAssertEqual(pasteboard.string, "Speaker A · 00:04\nHello")
        XCTAssertEqual(controller.feedback, "Transcript copied")
        controller.copyTranscript(Meeting())
        XCTAssertEqual(pasteboard.string, "Speaker A · 00:04\nHello")
        XCTAssertNotNil(controller.errorMessage)
    }

    func testShareOwnsTextFileUntilDismissalAndCanRepeat() throws {
        let controller = MeetingExportController()
        controller.share(Meeting(title: "Notes", notes: "First export"))
        let first = try XCTUnwrap(controller.sharedFile)
        controller.share(Meeting(notes: "A second tap must not replace the active file"))
        XCTAssertEqual(controller.sharedFile?.id, first.id)
        XCTAssertEqual(first.url.pathExtension, "txt")
        XCTAssertTrue(try String(contentsOf: first.url, encoding: .utf8).contains("First export"))
        controller.finishSharing()
        XCTAssertTrue(FileManager.default.fileExists(atPath: first.url.path))
        controller.dismissShare()
        XCTAssertFalse(FileManager.default.fileExists(atPath: first.url.path))
        controller.share(Meeting(notes: "Second export"))
        let second = try XCTUnwrap(controller.sharedFile)
        XCTAssertNotEqual(first.url, second.url)
        controller.dismissShare()
        controller.dismissShare()
        XCTAssertFalse(FileManager.default.fileExists(atPath: second.url.path))
    }

    func testShareFailureHasFeedbackAndAllowsRetry() throws {
        var shouldFail = true
        let controller = MeetingExportController(prepareFile: { meeting in
            if shouldFail { throw CocoaError(.fileWriteOutOfSpace) }
            return try PreparedTextExport(meeting: meeting)
        })
        controller.share(Meeting())
        XCTAssertNil(controller.sharedFile)
        XCTAssertNotNil(controller.errorMessage)
        XCTAssertFalse(controller.isPreparing)
        shouldFail = false
        controller.share(Meeting())
        XCTAssertNotNil(controller.sharedFile)
        controller.finishSharing(error: CocoaError(.fileWriteUnknown))
        XCTAssertNotNil(controller.errorMessage)
        controller.dismissShare()
    }
}
