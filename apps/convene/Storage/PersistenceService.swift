import Foundation
import AppKit

@MainActor
final class PersistenceService: ObservableObject {
    private let bookmarkKey = "outputFolderBookmark"

    @Published private(set) var outputFolderURL: URL?
    @Published private(set) var lastSavedFileURL: URL?
    @Published private(set) var lastUsedFallback = false
    @Published private(set) var lastError: String?

    var hasConfiguredOutputFolder: Bool {
        outputFolderURL != nil
    }

    init() {
        outputFolderURL = resolveStoredBookmark(forKey: bookmarkKey)
        if outputFolderURL == nil,
           let obsidianURL = resolveStoredBookmark(forKey: "obsidianFolderBookmark") {
            outputFolderURL = obsidianURL
            if let data = UserDefaults.standard.data(forKey: "obsidianFolderBookmark") {
                UserDefaults.standard.set(data, forKey: bookmarkKey)
            }
            UserDefaults.standard.removeObject(forKey: "obsidianFolderBookmark")
            logInfo("PersistenceService: migrated Obsidian folder to save folder")
        }
    }

    // MARK: - Folder picker

    func chooseOutputFolder(suggesting suggestion: URL? = nil) {
        let panel = NSOpenPanel()
        panel.title = "Choose where Convene saves meeting notes"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = outputFolderURL ?? suggestion ?? defaultSuggestedFolder()

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
            lastError = "Could not save folder access: \(error.localizedDescription)"
            logError("PersistenceService: bookmark save failed: \(error.localizedDescription)")
        }
    }

    func clearOutputFolder() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        outputFolderURL = nil
        lastError = nil
        logInfo("PersistenceService: output folder cleared")
    }

    private func defaultSuggestedFolder() -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let obsidianPath = home
            .appendingPathComponent("Library/Mobile Documents/iCloud~md~obsidian/Documents", isDirectory: true)
        if FileManager.default.fileExists(atPath: obsidianPath.path) {
            return obsidianPath
        }
        let icloudPath = home
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
        if FileManager.default.fileExists(atPath: icloudPath.path) {
            return icloudPath
        }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    private func resolveStoredBookmark(forKey key: String) -> URL? {
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
                logInfo("PersistenceService: bookmark stale, will refresh on next folder choose")
            }
            return url
        } catch {
            logError("PersistenceService: failed to resolve bookmark: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Save

    @discardableResult
    func save(_ meeting: Meeting) -> URL? {
        lastUsedFallback = false

        let rendered: MeetingFileWriter.Rendered
        do {
            rendered = try MeetingFileWriter.render(meeting)
        } catch {
            lastError = "Save failed: \(error.localizedDescription)"
            logError("PersistenceService: meeting encode failed: \(error.localizedDescription)")
            return nil
        }

        if let folder = outputFolderURL {
            do {
                let url = try writeFiles(rendered, folder: folder)
                lastSavedFileURL = url
                lastError = nil
                logInfo("PersistenceService: saved \(url.lastPathComponent)")
                return url
            } catch {
                lastError = "Output save failed; saved a local copy instead."
                logError("PersistenceService: output save failed: \(error.localizedDescription)")
            }
        }

        do {
            let folder = try localFallbackFolder()
            let url = try writeFiles(rendered, folder: folder)
            lastSavedFileURL = url
            lastUsedFallback = true
            if outputFolderURL == nil {
                lastError = nil
            }
            return url
        } catch {
            lastError = "Save failed: \(error.localizedDescription)"
            logError("PersistenceService: fallback save failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func writeFiles(_ rendered: MeetingFileWriter.Rendered, folder: URL) throws -> URL {
        let didStartScope = folder.startAccessingSecurityScopedResource()
        defer { if didStartScope { folder.stopAccessingSecurityScopedResource() } }
        return try MeetingFileWriter.write(rendered, to: folder)
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

    /// The most recently modified saved transcript (.md). Looked up from the output folder so it
    /// survives relaunches, falling back to the file saved this session.
    func latestTranscriptURL() -> URL? {
        guard let folder = outputFolderURL else { return lastSavedFileURL }
        let didStart = folder.startAccessingSecurityScopedResource()
        defer { if didStart { folder.stopAccessingSecurityScopedResource() } }
        let files = (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        let latest = files
            .filter { $0.pathExtension == "md" }
            .max { Self.modifiedDate($0) < Self.modifiedDate($1) }
        return latest ?? lastSavedFileURL
    }

    private static func modifiedDate(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    /// Open a saved note in Obsidian (notes live in the user's vault), falling back to the default app.
    func openFile(_ url: URL) {
        if openInObsidian(path: url.path) { return }
        NSWorkspace.shared.open(url)
    }

    /// Open a note in Obsidian via its URL scheme. Returns false if Obsidian isn't installed or the
    /// URL couldn't be built.
    private func openInObsidian(path: String) -> Bool {
        guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: "md.obsidian") != nil else { return false }
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "/-._~")
        guard let encoded = path.addingPercentEncoding(withAllowedCharacters: allowed),
              let obsidianURL = URL(string: "obsidian://open?path=\(encoded)") else {
            return false
        }
        NSWorkspace.shared.open(obsidianURL)
        return true
    }
}

extension PersistenceService: MeetingPersisting {}
