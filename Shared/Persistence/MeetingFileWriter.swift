import Foundation

/// Renders a meeting to its on-disk representation and writes the pair of files
/// (`<stem>.md` + `<stem>.transcript.json`). Shared by the macOS and iOS persistence
/// services, which keep their own bookmark resolution, folder pickers, fallback choice, and
/// security-scoped access — this owns only the format-and-write step they had in common.
enum MeetingFileWriter {
    struct Rendered {
        let stem: String
        let markdown: String
        let json: Data
    }

    /// Render a meeting to its filename stem, markdown, and transcript JSON. Throws if JSON
    /// encoding fails, letting callers report an encode error before touching the filesystem.
    static func render(_ meeting: Meeting) throws -> Rendered {
        Rendered(
            stem: MarkdownRenderer.filenameStem(for: meeting),
            markdown: MarkdownRenderer.renderMarkdown(meeting),
            json: try MarkdownRenderer.encodeJSON(meeting)
        )
    }

    /// Write the rendered files into `folder` (created if needed), returning the markdown URL.
    /// The caller is responsible for any security-scoped resource access around this call.
    @discardableResult
    static func write(_ rendered: Rendered, to folder: URL) throws -> URL {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let markdownURL = folder.appendingPathComponent("\(rendered.stem).md")
        let jsonURL = folder.appendingPathComponent("\(rendered.stem).transcript.json")
        try rendered.markdown.write(to: markdownURL, atomically: true, encoding: .utf8)
        try rendered.json.write(to: jsonURL, options: .atomic)
        return markdownURL
    }
}
