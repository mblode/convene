import Foundation

/// Human-readable exports, separate from the Markdown document saved to a notes vault.
enum MeetingTextExport {
    static func transcript(_ meeting: Meeting) -> String {
        let segments = meeting.transcript.filter {
            !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return TranscriptFormatter.mergedBlocks(segments).map { block in
            let name = TranscriptFormatter.displayName(
                for: block.speaker,
                selfName: meeting.selfName,
                othersName: meeting.othersName,
                diarizedSpeaker: block.diarizedSpeaker
            )
            let partial = block.isPartial ? " (partial)" : ""
            return
                "\(name) · \(TranscriptFormatter.timestampString(block.startedAt))\(partial)\n\(block.text)"
        }.joined(separator: "\n\n")
    }

    static func meeting(_ meeting: Meeting) -> String {
        var sections = [
            meeting.title,
            meeting.startedAt.formatted(date: .complete, time: .shortened)
        ]
        func append(_ title: String, _ content: String) {
            let content = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if !content.isEmpty { sections.append("\(title)\n\(content)") }
        }
        func bullets(_ title: String, _ values: [String]) {
            append(title, values.filter { !$0.isEmpty }.map { "• \($0)" }.joined(separator: "\n"))
        }
        if let summary = meeting.summary {
            append("Summary", summary.overview)
            for detail in summary.details { append(detail.title, detail.narrative) }
            bullets("Topics", summary.topics)
            bullets("Key points", summary.keyPoints)
            bullets("Decisions", summary.decisions)
            bullets("Action items", summary.actionItems)
            bullets("Open questions", summary.openQuestions)
            bullets("Follow-ups", summary.followUps)
        }
        append("Your notes", meeting.notes)
        append(
            "Key moments",
            meeting.keyMoments.sorted { $0.offset < $1.offset }.map {
                "\($0.formattedTimestamp) \($0.trimmedText.isEmpty ? "Flagged" : $0.trimmedText)"
            }.joined(separator: "\n"))
        if let error = meeting.recordingNotice { append("Recording information", error) }
        append("Transcript", transcript(meeting))
        return sections.joined(separator: "\n\n") + "\n"
    }
}

/// Owns one temporary .txt file for exactly one share presentation. Unique directories prevent
/// repeated exports with the same title from overwriting a file still being read by an extension.
final class PreparedTextExport: Identifiable {
    let id = UUID()
    let url: URL
    private let directory: URL

    init(meeting: Meeting, temporaryDirectory: URL = FileManager.default.temporaryDirectory) throws {
        directory = temporaryDirectory.appendingPathComponent("Convene-export-\(id)", isDirectory: true)
        url = directory.appendingPathComponent(MarkdownRenderer.filenameStem(for: meeting))
            .appendingPathExtension("txt")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try MeetingTextExport.meeting(meeting).write(to: url, atomically: true, encoding: .utf8)
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }

    func remove() {
        try? FileManager.default.removeItem(at: directory)
    }

    deinit { remove() }
}
