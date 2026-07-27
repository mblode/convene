import Foundation

/// The Meetings tab's data source.
///
/// Every save already writes a structured `<stem>.transcript.json` into the app-internal
/// transcripts directory, deliberately kept out of the user's notes folder (see
/// `MeetingFileWriter`). That file is a complete encoded `Meeting`, so the library is a read view
/// over it: no second store to keep in sync, and it works whether the markdown went to the local
/// folder or to an iCloud Drive vault the app can only reach while security-scoped.
@MainActor
final class MeetingLibrary: ObservableObject {
    @Published private(set) var meetings: [Meeting] = []
    @Published private(set) var lastError: String?

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    func reload() {
        guard let directory = MeetingFileWriter.internalTranscriptDirectory() else {
            lastError = "Could not find the transcripts folder"
            return
        }

        // The directory is created by the first save, so its absence means an empty library rather
        // than a failure worth showing.
        guard FileManager.default.fileExists(atPath: directory.path) else {
            meetings = []
            lastError = nil
            return
        }

        let files: [URL]
        do {
            files = try FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: nil)
        } catch {
            lastError = "Could not read saved meetings: \(error.localizedDescription)"
            logError("MeetingLibrary: listing failed: \(error.localizedDescription)")
            return
        }

        var loaded: [Meeting] = []
        for file in files where file.lastPathComponent.hasSuffix(".transcript.json") {
            do {
                loaded.append(try Self.decoder.decode(Meeting.self, from: Data(contentsOf: file)))
            } catch {
                // One unreadable file shouldn't hide the rest of the library.
                logError("MeetingLibrary: skipped \(file.lastPathComponent): \(error.localizedDescription)")
            }
        }

        meetings = loaded.sorted { $0.startedAt > $1.startedAt }
        lastError = nil
    }

    /// Remove a meeting: its transcript JSON, plus the markdown wherever it was written.
    func delete(_ meeting: Meeting, markdownFolders: [URL]) {
        let stem = MarkdownRenderer.filenameStem(for: meeting)
        let fileManager = FileManager.default

        if let directory = MeetingFileWriter.internalTranscriptDirectory() {
            remove(directory.appendingPathComponent("\(stem).transcript.json"), using: fileManager)
        }

        for folder in markdownFolders {
            let scoped = folder.startAccessingSecurityScopedResource()
            defer { if scoped { folder.stopAccessingSecurityScopedResource() } }
            remove(folder.appendingPathComponent("\(stem).md"), using: fileManager)
        }

        meetings.removeAll { $0.id == meeting.id }
        logInfo("MeetingLibrary: deleted \(stem)")
    }

    private func remove(_ url: URL, using fileManager: FileManager) {
        guard fileManager.fileExists(atPath: url.path) else { return }
        do {
            try fileManager.removeItem(at: url)
        } catch {
            lastError = "Could not delete \(url.lastPathComponent): \(error.localizedDescription)"
            logError(
                "MeetingLibrary: delete failed for \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }
}
