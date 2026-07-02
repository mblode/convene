import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class MobilePersistenceService: ObservableObject {
    private let bookmarkKey = "vaultFolderBookmark"

    @Published private(set) var vaultFolderURL: URL?
    @Published private(set) var lastSavedFileURL: URL?
    @Published private(set) var lastError: String?
    /// True when the last save fell back to the app's local folder instead of the vault.
    @Published private(set) var lastUsedFallback = false

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
        lastUsedFallback = false
        let rendered: MeetingFileWriter.Rendered
        do {
            rendered = try MeetingFileWriter.render(meeting)
        } catch {
            lastError = "Save failed: \(error.localizedDescription)"
            return nil
        }

        if let folder = vaultFolderURL {
            if let url = writeToFolder(folder, rendered: rendered) {
                lastSavedFileURL = url
                lastError = nil
                return url
            }
        }

        // Fallback to app's Documents directory
        if let fallback = fallbackFolder() {
            if let url = writeToFolder(fallback, rendered: rendered) {
                lastSavedFileURL = url
                lastUsedFallback = true
                if vaultFolderURL != nil {
                    lastError = "Vault save failed; saved locally instead"
                }
                return url
            }
        }

        lastError = "Could not save meeting"
        return nil
    }

    private func writeToFolder(_ folder: URL, rendered: MeetingFileWriter.Rendered) -> URL? {
        let didStartScope = folder.startAccessingSecurityScopedResource()
        defer { if didStartScope { folder.stopAccessingSecurityScopedResource() } }

        do {
            let markdownURL = try MeetingFileWriter.write(rendered, to: folder)
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

extension MobilePersistenceService: MeetingPersisting {}
