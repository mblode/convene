import XCTest

@testable import Convene

final class MeetingFileWriterTests: XCTestCase {
    private var outputFolder: URL!
    private var writtenJSON: URL?

    override func setUpWithError() throws {
        outputFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("convene-writer-tests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: outputFolder)
        // The writer targets the real Application Support directory, so clean up after ourselves.
        if let writtenJSON { try? FileManager.default.removeItem(at: writtenJSON) }
    }

    func testWritesOnlyMarkdownToOutputFolder() throws {
        let rendered = try MeetingFileWriter.render(makeMeeting(title: "Standup"))
        let internalDirectory = try XCTUnwrap(MeetingFileWriter.internalTranscriptDirectory())
        writtenJSON = internalDirectory.appendingPathComponent("\(rendered.stem).transcript.json")

        let markdownURL = try MeetingFileWriter.write(rendered, to: outputFolder)

        XCTAssertEqual(markdownURL.lastPathComponent, "\(rendered.stem).md")
        let contents = try FileManager.default.contentsOfDirectory(atPath: outputFolder.path)
        XCTAssertEqual(contents, ["\(rendered.stem).md"])
    }
}
