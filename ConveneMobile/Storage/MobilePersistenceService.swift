import Foundation

/// Writes meeting markdown to disk on iOS.
///
/// By default notes land in the app's own `Documents/Convene`, which `UIFileSharingEnabled` and
/// `LSSupportsOpeningDocumentsInPlace` expose in the Files app — so "your notes stay in a folder
/// you own" holds without the user having to pick anything. Picking a folder (an iCloud Drive
/// Obsidian vault, say) writes there instead, through a security-scoped bookmark, and falls back
/// to `Documents/Convene` if that folder is unreachable rather than losing the meeting.
@MainActor
final class MobilePersistenceService: ObservableObject {
    private let bookmarkKey = "vaultFolderBookmark"

    @Published private(set) var vaultFolderURL: URL?
    @Published private(set) var lastSavedFileURL: URL?
    @Published private(set) var lastError: String?
    /// True when the last save fell back to the local folder instead of the chosen one.
    @Published private(set) var lastUsedFallback = false

    var hasConfiguredVault: Bool { vaultFolderURL != nil }

    /// Where the next save will go, for display in Settings.
    var saveFolderDisplayName: String {
        vaultFolderURL?.lastPathComponent ?? "On My iPhone › Convene"
    }

    init() {
        vaultFolderURL = resolveStoredBookmark()
    }

    // MARK: - Folder selection

    func handlePickedFolder(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            lastError = "Could not get access to that folder"
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
            logInfo("MobilePersistenceService: save folder set to \(url.path)")
        } catch {
            lastError = "Could not keep access to that folder: \(error.localizedDescription)"
            logError("MobilePersistenceService: bookmark save failed: \(error.localizedDescription)")
        }
    }

    func clearVaultFolder() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        vaultFolderURL = nil
        lastError = nil
    }

    /// Every folder a meeting may have been written to, newest choice first. Used when deleting a
    /// meeting from the library, which has to find the markdown wherever it ended up.
    var candidateFolders: [URL] {
        [vaultFolderURL, Self.localFolder].compactMap { $0 }
    }

    /// The app's own notes folder, visible in Files. Always available, unlike a picked folder.
    static var localFolder: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Convene", isDirectory: true)
    }

    // MARK: - Saving

    @discardableResult
    func save(_ meeting: Meeting) -> URL? {
        lastUsedFallback = false
        let rendered: MeetingFileWriter.Rendered
        do {
            rendered = try MeetingFileWriter.render(meeting)
        } catch {
            lastError = "Could not save the meeting: \(error.localizedDescription)"
            return nil
        }

        if let folder = vaultFolderURL, let url = writeToFolder(folder, rendered: rendered) {
            lastSavedFileURL = url
            lastError = nil
            return url
        }

        if let fallback = Self.localFolder, let url = writeToFolder(fallback, rendered: rendered) {
            lastSavedFileURL = url
            lastUsedFallback = vaultFolderURL != nil
            lastError = vaultFolderURL == nil ? nil : "Couldn't reach your folder, so it saved to Convene on this iPhone"
            return url
        }

        lastError = "Could not save the meeting"
        return nil
    }

    private func writeToFolder(_ folder: URL, rendered: MeetingFileWriter.Rendered) -> URL? {
        let scoped = folder.startAccessingSecurityScopedResource()
        defer { if scoped { folder.stopAccessingSecurityScopedResource() } }

        do {
            let markdownURL = try MeetingFileWriter.write(rendered, to: folder)
            logInfo("MobilePersistenceService: saved \(markdownURL.lastPathComponent)")
            return markdownURL
        } catch {
            logError("MobilePersistenceService: write to \(folder.lastPathComponent) failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Bookmarks

    private func resolveStoredBookmark() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        do {
            var stale = false
            let url = try URL(resolvingBookmarkData: data, bookmarkDataIsStale: &stale)
            if stale {
                refreshBookmark(for: url)
            }
            return url
        } catch {
            // A folder the user moved or deleted. Drop the bookmark so Settings shows the local
            // folder rather than a path that will fail on every save.
            UserDefaults.standard.removeObject(forKey: bookmarkKey)
            logError("MobilePersistenceService: dropped unresolvable bookmark: \(error.localizedDescription)")
            return nil
        }
    }

    /// Rewrite a stale bookmark in place so it doesn't have to be re-resolved on every launch.
    private func refreshBookmark(for url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let refreshed = try url.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(refreshed, forKey: bookmarkKey)
            logInfo("MobilePersistenceService: refreshed stale bookmark")
        } catch {
            logError("MobilePersistenceService: could not refresh stale bookmark: \(error.localizedDescription)")
        }
    }
}

extension MobilePersistenceService: MeetingPersisting {}
