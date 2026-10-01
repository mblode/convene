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
        let firstURL = try XCTUnwrap(controller.sharedFile?.url)
        let firstID = controller.sharedFile?.id
        controller.share(Meeting(notes: "A second tap must not replace the active file"))
        XCTAssertEqual(controller.sharedFile?.id, firstID)
        XCTAssertEqual(firstURL.pathExtension, "txt")
        XCTAssertTrue(try String(contentsOf: firstURL, encoding: .utf8).contains("First export"))
        controller.finishSharing(id: try XCTUnwrap(firstID))
        XCTAssertTrue(FileManager.default.fileExists(atPath: firstURL.path))
        controller.dismissShare()
        XCTAssertFalse(FileManager.default.fileExists(atPath: firstURL.path))
        controller.share(Meeting(notes: "Second export"))
        let secondURL = try XCTUnwrap(controller.sharedFile?.url)
        XCTAssertNotEqual(firstURL, secondURL)
        controller.dismissShare()
        controller.dismissShare()
        XCTAssertFalse(FileManager.default.fileExists(atPath: secondURL.path))
    }

    func testSwipeDismissalDoesNotRemoveFileStillOwnedByAnActivity() throws {
        let controller = MeetingExportController()
        controller.share(Meeting(notes: "Keep until the activity is finished"))
        // Models the item source retaining its export after SwiftUI dismisses the presentation.
        var activityExport = controller.sharedFile
        let url = try XCTUnwrap(activityExport?.url)
        controller.dismissShare()
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        activityExport = nil
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testLateCompletionCannotDismissANewerShare() throws {
        let controller = MeetingExportController()
        controller.share(Meeting(notes: "First"))
        let firstID = try XCTUnwrap(controller.sharedFile?.id)
        controller.dismissShare()
        controller.share(Meeting(notes: "Second"))
        let secondID = try XCTUnwrap(controller.sharedFile?.id)
        controller.finishSharing(id: firstID, error: CocoaError(.fileWriteUnknown))
        XCTAssertEqual(controller.sharedFile?.id, secondID)
        XCTAssertNil(controller.errorMessage)
        controller.dismissShare()
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
        controller.finishSharing(
            id: try XCTUnwrap(controller.sharedFile?.id), error: CocoaError(.fileWriteUnknown))
        XCTAssertNotNil(controller.errorMessage)
        controller.dismissShare()
    }
}
