import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class MobilePersistenceService: ObservableObject {
    private let bookmarkKey = "vaultFolderBookmark"

    @Published private(set) var vaultFolderURL: URL?
    @Published private(set) var lastSavedFileURL: URL?
    @Published private(set) var lastError: String?

    var hasConfiguredVault: Bool { vaultFolderURL != nil }

    init() {
        vaultFolderURL = resolveStoredBookmark()
    }

    func handlePickedFolder(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            lastError = "Could not access selected folder"
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let bookmark = try url.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
            vaultFolderURL = url
            lastError = nil
            logInfo("MobilePersistenceService: vault folder set to \(url.path)")
        } catch {
            lastError = "Could not save folder access: \(error.localizedDescription)"
            logError("MobilePersistenceService: bookmark save failed: \(error.localizedDescription)")
        }
    }

    func clearVaultFolder() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        vaultFolderURL = nil
        lastSavedFileURL = nil
        lastError = nil
    }

    @discardableResult
    func save(_ meeting: Meeting) -> URL? {
        let baseName = MarkdownRenderer.filenameStem(for: meeting)
        let markdown = MarkdownRenderer.renderMarkdown(meeting)

        let jsonData: Data
        do {
            jsonData = try MarkdownRenderer.encodeJSON(meeting)
        } catch {
            lastError = "Save failed: \(error.localizedDescription)"
            return nil
        }

        if let folder = vaultFolderURL {
            if let url = writeToFolder(folder, baseName: baseName, markdown: markdown, jsonData: jsonData) {
                lastSavedFileURL = url
                lastError = nil
                return url
            }
        }

        // Fallback to app's Documents directory
        if let fallback = fallbackFolder() {
            if let url = writeToFolder(fallback, baseName: baseName, markdown: markdown, jsonData: jsonData) {
                lastSavedFileURL = url
                if vaultFolderURL != nil {
                    lastError = "Vault save failed; saved locally instead"
                }
                return url
            }
        }

        lastError = "Could not save meeting"
        return nil
    }

    private func writeToFolder(_ folder: URL, baseName: String, markdown: String, jsonData: Data) -> URL? {
        let didStartScope = folder.startAccessingSecurityScopedResource()
        defer { if didStartScope { folder.stopAccessingSecurityScopedResource() } }

        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let markdownURL = folder.appendingPathComponent("\(baseName).md")
            let jsonURL = folder.appendingPathComponent("\(baseName).transcript.json")
            try markdown.write(to: markdownURL, atomically: true, encoding: .utf8)
            try jsonData.write(to: jsonURL, options: .atomic)
            logInfo("MobilePersistenceService: saved \(markdownURL.lastPathComponent)")
            return markdownURL
        } catch {
            logError("MobilePersistenceService: write failed: \(error.localizedDescription)")
            lastError = "Save failed: \(error.localizedDescription)"
            return nil
        }
    }

    private func fallbackFolder() -> URL? {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        return docs.appendingPathComponent("Convene", isDirectory: true)
    }

    private func resolveStoredBookmark() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        do {
            var stale = false
            let url = try URL(
                resolvingBookmarkData: data,
                bookmarkDataIsStale: &stale
            )
            if stale {
                logInfo("MobilePersistenceService: bookmark stale, will refresh on next folder pick")
            }
            return url
        } catch {
            logError("MobilePersistenceService: failed to resolve bookmark: \(error.localizedDescription)")
            return nil
        }
    }
}
