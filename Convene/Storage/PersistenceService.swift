import Foundation
import AppKit

/// Persists meetings to a user-chosen folder. The folder URL is held as a security-scoped
/// app-scope bookmark in UserDefaults so the app retains read/write access across launches.
@MainActor
final class PersistenceService: ObservableObject {
    private let outputBookmarkKey = "outputFolderBookmark"
    private let obsidianBookmarkKey = "obsidianFolderBookmark"

    @Published private(set) var outputFolderURL: URL?
    @Published private(set) var obsidianFolderURL: URL?
    @Published private(set) var lastSavedFileURL: URL?
    @Published private(set) var lastObsidianFileURL: URL?
    @Published private(set) var lastPrimaryWasFallback = false
    @Published private(set) var lastError: String?
    @Published private(set) var lastObsidianError: String?

    var hasConfiguredOutputFolder: Bool {
        outputFolderURL != nil
    }

    init() {
        outputFolderURL = resolveStoredBookmark(forKey: outputBookmarkKey, label: "output")
        obsidianFolderURL = resolveStoredBookmark(forKey: obsidianBookmarkKey, label: "Obsidian")
    }

    // MARK: - Folder pickers

    func chooseOutputFolder(suggesting suggestion: URL? = nil) {
        chooseFolder(
            title: "Choose where Convene saves meeting notes",
            currentURL: outputFolderURL,
            suggestion: suggestion ?? defaultSuggestedFolder(),
            bookmarkKey: outputBookmarkKey
        ) { [weak self] url in
            self?.outputFolderURL = url
            self?.lastError = nil
            logInfo("PersistenceService: output folder set to \(url.path)")
        }
    }

    func chooseObsidianFolder(suggesting suggestion: URL? = nil) {
        chooseFolder(
            title: "Choose an Obsidian vault or folder",
            currentURL: obsidianFolderURL,
            suggestion: suggestion ?? defaultObsidianSuggestion() ?? defaultSuggestedFolder(),
            bookmarkKey: obsidianBookmarkKey
        ) { [weak self] url in
            self?.obsidianFolderURL = url
            self?.lastObsidianError = nil
            logInfo("PersistenceService: Obsidian folder set to \(url.path)")
        }
    }

    func clearObsidianFolder() {
        UserDefaults.standard.removeObject(forKey: obsidianBookmarkKey)
        obsidianFolderURL = nil
        lastObsidianFileURL = nil
        lastObsidianError = nil
        logInfo("PersistenceService: Obsidian export disabled")
    }

    private func chooseFolder(
        title: String,
        currentURL: URL?,
        suggestion: URL?,
        bookmarkKey: String,
        onSelect: (URL) -> Void
    ) {
        let panel = NSOpenPanel()
        panel.title = title
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = currentURL ?? suggestion

        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { return }

        do {
            let bookmark = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
            onSelect(url)
        } catch {
            let message = "Could not save folder access: \(error.localizedDescription)"
            if bookmarkKey == obsidianBookmarkKey {
                lastObsidianError = message
            } else {
                lastError = message
            }
            logError("PersistenceService: bookmark save failed: \(error.localizedDescription)")
        }
    }

    /// iCloud Drive root (`~/Library/Mobile Documents/com~apple~CloudDocs/`) if it exists,
    /// otherwise the user's Documents directory. We point the picker here as a starting
    /// suggestion only; the user makes the final choice in NSOpenPanel.
    private func defaultSuggestedFolder() -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let icloudPath = home
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
        if FileManager.default.fileExists(atPath: icloudPath.path) {
            return icloudPath
        }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    private func defaultObsidianSuggestion() -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let obsidianPath = home
            .appendingPathComponent("Library/Mobile Documents/iCloud~md~obsidian/Documents", isDirectory: true)
        if FileManager.default.fileExists(atPath: obsidianPath.path) {
            return obsidianPath
        }
        return nil
    }

    private func resolveStoredBookmark(forKey key: String, label: String) -> URL? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        do {
            var stale = false
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
            if stale {
                logInfo("PersistenceService: \(label) bookmark stale, will refresh on next folder choose")
            }
            return url
        } catch {
            logError("PersistenceService: failed to resolve \(label) bookmark: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Save

    /// Writes the meeting as Markdown plus a JSON transcript sidecar to the primary notes
    /// folder. If no folder is configured, or the configured folder fails, Convene writes a
    /// local fallback copy so stopping a recording never drops the meeting.
    @discardableResult
    func save(_ meeting: Meeting) -> URL? {
        lastObsidianFileURL = nil
        lastObsidianError = nil
        lastPrimaryWasFallback = false

        let baseName = filenameStem(for: meeting)
        let markdown = renderMarkdown(meeting)

        let jsonData: Data
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            jsonData = try encoder.encode(meeting)
        } catch {
            lastError = "Save failed: \(error.localizedDescription)"
            logError("PersistenceService: meeting encode failed: \(error.localizedDescription)")
            return nil
        }

        let primary = savePrimary(
            baseName: baseName,
            markdown: markdown,
            jsonData: jsonData
        )
        let obsidianURL = exportToObsidian(
            baseName: baseName,
            markdown: markdown,
            primaryFolder: primary?.folderURL
        )

        if let primary {
            lastSavedFileURL = primary.markdownURL
            lastPrimaryWasFallback = primary.usedFallback
            if lastError == nil {
                logInfo("PersistenceService: saved \(primary.markdownURL.lastPathComponent)")
            }
            return primary.markdownURL
        }

        if let obsidianURL {
            lastSavedFileURL = obsidianURL
            return obsidianURL
        }

        return nil
    }

    private struct PrimarySave {
        let markdownURL: URL
        let folderURL: URL
        let usedFallback: Bool
    }

    private func savePrimary(baseName: String, markdown: String, jsonData: Data) -> PrimarySave? {
        if let folder = outputFolderURL {
            do {
                let url = try writePrimaryFiles(
                    baseName: baseName,
                    markdown: markdown,
                    jsonData: jsonData,
                    folder: folder
                )
                lastError = nil
                return PrimarySave(markdownURL: url, folderURL: folder, usedFallback: false)
            } catch {
                lastError = "Output save failed; saved a local copy instead."
                logError("PersistenceService: output save failed: \(error.localizedDescription)")
            }
        }

        do {
            let folder = try localFallbackFolder()
            let url = try writePrimaryFiles(
                baseName: baseName,
                markdown: markdown,
                jsonData: jsonData,
                folder: folder
            )
            if outputFolderURL == nil {
                lastError = nil
            }
            return PrimarySave(markdownURL: url, folderURL: folder, usedFallback: true)
        } catch {
            lastError = "Save failed: \(error.localizedDescription)"
            logError("PersistenceService: fallback save failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func exportToObsidian(baseName: String, markdown: String, primaryFolder: URL?) -> URL? {
        guard let folder = obsidianFolderURL else { return nil }

        if let primaryFolder, sameDirectory(primaryFolder, folder) {
            let url = primaryFolder.appendingPathComponent("\(baseName).md")
            lastObsidianFileURL = url
            lastObsidianError = nil
            return url
        }

        let didStartScope = folder.startAccessingSecurityScopedResource()
        defer { if didStartScope { folder.stopAccessingSecurityScopedResource() } }

        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let markdownURL = folder.appendingPathComponent("\(baseName).md")
            try markdown.write(to: markdownURL, atomically: true, encoding: .utf8)
            lastObsidianFileURL = markdownURL
            lastObsidianError = nil
            logInfo("PersistenceService: exported Obsidian note \(markdownURL.lastPathComponent)")
            return markdownURL
        } catch {
            lastObsidianError = "Obsidian export failed: \(error.localizedDescription)"
            logError("PersistenceService: Obsidian export failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func writePrimaryFiles(baseName: String, markdown: String, jsonData: Data, folder: URL) throws -> URL {
        let didStartScope = folder.startAccessingSecurityScopedResource()
        defer { if didStartScope { folder.stopAccessingSecurityScopedResource() } }

        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let markdownURL = folder.appendingPathComponent("\(baseName).md")
        let jsonURL = folder.appendingPathComponent("\(baseName).transcript.json")

        try markdown.write(to: markdownURL, atomically: true, encoding: .utf8)
        try jsonData.write(to: jsonURL, options: .atomic)
        return markdownURL
    }

    private func localFallbackFolder() throws -> URL {
        guard let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        let folder = applicationSupport
            .appendingPathComponent("Convene", isDirectory: true)
            .appendingPathComponent("Meetings", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func openFile(_ url: URL) {
        NSWorkspace.shared.open(url)
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
        out += "tags:\n"
        out += "  - meeting\n"
        out += "  - convene\n"
        out += "source: convene\n"
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

        if !meeting.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            out += "## Notes\n\n"
            out += meeting.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            out += "\n\n"
        }

        if let transcriptionError = meeting.transcriptionError?.trimmingCharacters(in: .whitespacesAndNewlines),
           !transcriptionError.isEmpty {
            out += "## Transcription Error\n\n"
            out += transcriptionError
            out += "\n\n"
        }

        let transcriptSegments = meeting.transcript.filter {
            !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if !transcriptSegments.isEmpty {
            out += "## Transcript\n\n"
            for segment in transcriptSegments {
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

    private func sameDirectory(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.standardizedFileURL.path == rhs.standardizedFileURL.path
    }
}
