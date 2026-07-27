import Foundation

/// Renders a meeting to its on-disk representation and writes it out. The user-facing markdown
/// (`<stem>.md`) goes to the chosen output folder; the structured `<stem>.transcript.json` is an
/// app-internal artifact kept out of the vault (see `internalTranscriptDirectory`). Shared by the
/// macOS and iOS persistence services, which keep their own bookmark resolution, folder pickers,
/// fallback choice, and security-scoped access — this owns only the format-and-write step they
/// have in common.
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

    /// Write the user-facing markdown into `folder` (created if needed), returning its URL. The
    /// caller is responsible for any security-scoped resource access around this call. The
    /// structured transcript JSON is written separately by `writeTranscriptJSON` so it never lands
    /// in the user's vault.
    @discardableResult
    static func write(_ rendered: Rendered, to folder: URL) throws -> URL {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let markdownURL = folder.appendingPathComponent("\(rendered.stem).md")
        try rendered.markdown.write(to: markdownURL, atomically: true, encoding: .utf8)
        writeTranscriptJSON(rendered)
        return markdownURL
    }

    /// The app-internal directory holding structured transcript JSON, kept out of the output
    /// folder. Mirrors the `Application Support/Convene/<subfolder>` convention used by the WAL.
    static func internalTranscriptDirectory() -> URL? {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else { return nil }
        return appSupport
            .appendingPathComponent("Convene", isDirectory: true)
            .appendingPathComponent("Transcripts", isDirectory: true)
    }

    /// Write the transcript JSON into the app-internal directory. Failures here are non-fatal to a
    /// save: the markdown is the source of truth, so we log and continue rather than throw.
    private static func writeTranscriptJSON(_ rendered: Rendered) {
        guard let directory = internalTranscriptDirectory() else { return }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let jsonURL = directory.appendingPathComponent("\(rendered.stem).transcript.json")
            try rendered.json.write(to: jsonURL, options: .atomic)
        } catch {
            logError("MeetingFileWriter: internal transcript JSON write failed: \(error.localizedDescription)")
        }
    }
}
