import Foundation

final class TranscriptWALService: Sendable {
    private struct Header: Codable {
        let version: Int
        let meetingId: UUID
        let title: String
        let attendees: [String]
        let startedAt: Date
    }

    private let queue = DispatchQueue(label: "co.blode.convene.wal")
    private let directory: URL
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private nonisolated(unsafe) var fileHandle: FileHandle?
    private nonisolated(unsafe) var walURL: URL?

    init(directory: URL = TranscriptWALService.defaultDirectory()) {
        self.directory = directory
    }

    func beginSession(meetingId: UUID, title: String, attendees: [String], startedAt: Date) {
        queue.sync {
            let dir = directory
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

            let url = dir.appendingPathComponent("\(meetingId.uuidString).wal.jsonl")
            FileManager.default.createFile(atPath: url.path, contents: nil)

            guard let handle = try? FileHandle(forWritingTo: url) else {
                logError("TranscriptWAL: failed to open \(url.path)")
                return
            }

            let header = Header(
                version: 1,
                meetingId: meetingId,
                title: title,
                attendees: attendees,
                startedAt: startedAt
            )
            if let data = try? encoder.encode(header) {
                handle.write(data)
                handle.write(Data("\n".utf8))
                handle.synchronizeFile()
            }

            self.fileHandle = handle
            self.walURL = url
            logInfo("TranscriptWAL: began session \(meetingId)")
        }
    }

    func appendSegment(_ segment: TranscriptSegment) {
        queue.async { [encoder] in
            guard let handle = self.fileHandle else { return }
            guard let data = try? encoder.encode(segment) else { return }
            handle.write(data)
            handle.write(Data("\n".utf8))
            handle.synchronizeFile()
        }
    }

    /// Appends a flagged key moment. Stored as its own line; recovery disambiguates it from
    /// transcript segments by their disjoint key sets (`offset`/`createdAt` vs `speaker`/`isFinal`).
    func appendKeyMoment(_ moment: KeyMoment) {
        queue.async { [encoder] in
            guard let handle = self.fileHandle else { return }
            guard let data = try? encoder.encode(moment) else { return }
            handle.write(data)
            handle.write(Data("\n".utf8))
            handle.synchronizeFile()
        }
    }

    @discardableResult
    func endSession() -> URL? {
        queue.sync {
            fileHandle?.closeFile()
            fileHandle = nil
            let url = walURL
            walURL = nil
            if let url {
                logInfo("TranscriptWAL: ended session \(url.lastPathComponent)")
            }
            return url
        }
    }

    // MARK: - Recovery

    func findOrphanedWALs() -> [URL] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        ) else { return [] }
        return contents.filter { $0.pathExtension == "jsonl" }
    }

    static func recoverMeeting(from walURL: URL) throws -> Meeting {
        let text = try String(contentsOf: walURL, encoding: .utf8)
        let lines = text.components(separatedBy: "\n").filter { !$0.isEmpty }
        guard let headerLine = lines.first,
              let headerData = headerLine.data(using: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let header = try decoder.decode(Header.self, from: headerData)

        var segments: [TranscriptSegment] = []
        var keyMoments: [KeyMoment] = []
        for line in lines.dropFirst() {
            guard let data = line.data(using: .utf8) else { continue }
            if let segment = try? decoder.decode(TranscriptSegment.self, from: data) {
                segments.append(segment)
            } else if let moment = try? decoder.decode(KeyMoment.self, from: data) {
                keyMoments.append(moment)
            }
        }

        let lastOffset = max(segments.last?.endedAt ?? 0, keyMoments.map(\.offset).max() ?? 0)
        let endedAt = lastOffset > 0
            ? header.startedAt.addingTimeInterval(lastOffset)
            : header.startedAt

        return Meeting(
            id: header.meetingId,
            title: "[Recovered] \(header.title)",
            attendees: header.attendees,
            startedAt: header.startedAt,
            endedAt: endedAt,
            transcript: segments,
            keyMoments: keyMoments,
            notes: "",
            transcriptionError: segments.isEmpty ? nil : "Recovered from crash — speaker labels not available"
        )
    }

    static func deleteWAL(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    static func defaultDirectory() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        return appSupport
            .appendingPathComponent("Convene", isDirectory: true)
            .appendingPathComponent("WAL", isDirectory: true)
    }
}
