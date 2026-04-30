import Foundation
import AppKit

/// Persists meetings to a user-chosen folder. The folder URL is held as a security-scoped
/// app-scope bookmark in UserDefaults so the app retains read/write access across launches.
@MainActor
final class PersistenceService: ObservableObject {
    private let bookmarkKey = "outputFolderBookmark"

    @Published private(set) var outputFolderURL: URL?
    @Published private(set) var lastSavedFileURL: URL?
    @Published private(set) var lastError: String?

    init() {
        outputFolderURL = resolveStoredBookmark()
    }

    // MARK: - Folder picker

    func chooseOutputFolder(suggesting suggestion: URL? = nil) {
        let panel = NSOpenPanel()
        panel.title = "Choose where Convene saves meeting notes"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = suggestion ?? outputFolderURL ?? defaultSuggestedFolder()

        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { return }

        do {
            let bookmark = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
            outputFolderURL = url
            lastError = nil
            logInfo("PersistenceService: output folder set to \(url.path)")
        } catch {
            lastError = "Could not save folder bookmark: \(error.localizedDescription)"
            logError("PersistenceService: bookmark save failed: \(error.localizedDescription)")
        }
    }

    /// iCloud Drive root (`~/Library/Mobile Documents/com~apple~CloudDocs/`) if it exists,
    /// otherwise the user's Documents directory. We point the picker here as a starting
    /// suggestion only — the user makes the final choice in NSOpenPanel.
    private func defaultSuggestedFolder() -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let icloudPath = home
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
        if FileManager.default.fileExists(atPath: icloudPath.path) {
            return icloudPath
        }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    private func resolveStoredBookmark() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        do {
            var stale = false
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
            if stale {
                logInfo("PersistenceService: bookmark stale, will refresh on next chooseOutputFolder")
            }
            return url
        } catch {
            logError("PersistenceService: failed to resolve bookmark: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Save

    /// Writes the meeting as a Markdown file plus a JSON transcript sidecar.
    /// Returns the URL of the Markdown file, or nil on failure.
    @discardableResult
    func save(_ meeting: Meeting) -> URL? {
        guard let folder = outputFolderURL else {
            lastError = "Output folder not set — open Settings to choose one."
            return nil
        }

        let didStartScope = folder.startAccessingSecurityScopedResource()
        defer { if didStartScope { folder.stopAccessingSecurityScopedResource() } }

        let baseName = filenameStem(for: meeting)
        let markdownURL = folder.appendingPathComponent("\(baseName).md")
        let jsonURL = folder.appendingPathComponent("\(baseName).transcript.json")

        do {
            let markdown = renderMarkdown(meeting)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(meeting)

            try markdown.write(to: markdownURL, atomically: true, encoding: .utf8)
            try jsonData.write(to: jsonURL, options: .atomic)

            lastSavedFileURL = markdownURL
            lastError = nil
            logInfo("PersistenceService: saved \(markdownURL.lastPathComponent)")
            return markdownURL
        } catch {
            lastError = "Save failed: \(error.localizedDescription)"
            logError("PersistenceService: save failed: \(error.localizedDescription)")
            return nil
        }
    }

    func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    // MARK: - Filename + Markdown rendering

    private func filenameStem(for meeting: Meeting) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HHmmss"
        let datePart = formatter.string(from: meeting.startedAt)
        let titlePart = sanitize(meeting.title)
        let idPart = meeting.id.uuidString.prefix(8).lowercased()
        return "\(datePart) - \(titlePart) - \(idPart)"
    }

    private func sanitize(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = trimmed.replacingOccurrences(
            of: #"[\/:*?"<>|]"#,
            with: "-",
            options: .regularExpression
        )
        return cleaned.isEmpty ? "Untitled" : String(cleaned.prefix(80))
    }

    private func renderMarkdown(_ meeting: Meeting) -> String {
        let isoStart = ISO8601DateFormatter().string(from: meeting.startedAt)
        let durationMinutes: Int = {
            guard let end = meeting.endedAt else { return 0 }
            return max(0, Int(end.timeIntervalSince(meeting.startedAt) / 60))
        }()

        var out = ""
        out += "---\n"
        out += "title: \(yamlEscape(meeting.title))\n"
        out += "date: \(isoStart)\n"
        out += "duration_minutes: \(durationMinutes)\n"
        if !meeting.attendees.isEmpty {
            out += "attendees:\n"
            for attendee in meeting.attendees {
                out += "  - \(yamlEscape(attendee))\n"
            }
        }
        if let audio = meeting.audioFilename {
            out += "audio: \(yamlEscape(audio))\n"
        }
        out += "---\n\n"

        out += "# \(meeting.title)\n\n"

        if !meeting.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            out += "## Notes\n\n"
            out += meeting.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            out += "\n\n"
        }

        if let summary = meeting.summary {
            out += "## Summary\n\n"
            out += summary.overview
            out += "\n\n"

            if !summary.keyPoints.isEmpty {
                out += "### Key points\n\n"
                for point in summary.keyPoints { out += "- \(point)\n" }
                out += "\n"
            }
            if !summary.decisions.isEmpty {
                out += "### Decisions\n\n"
                for decision in summary.decisions { out += "- \(decision)\n" }
                out += "\n"
            }
            if !summary.actionItems.isEmpty {
                out += "### Action items\n\n"
                for item in summary.actionItems { out += "- [ ] \(item)\n" }
                out += "\n"
            }
        }

        if !meeting.transcript.isEmpty {
            out += "## Transcript\n\n"
            for segment in meeting.transcript where !segment.text.isEmpty {
                let mm = Int(segment.startedAt) / 60
                let ss = Int(segment.startedAt) % 60
                let stamp = String(format: "%02d:%02d", mm, ss)
                out += "**\(segment.speaker.displayName) [\(stamp)]:** \(segment.text)\n\n"
            }
        }

        return out
    }

    private func yamlEscape(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }
}
