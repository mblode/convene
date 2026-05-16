import Foundation

enum MarkdownRenderer {
    static func filenameStem(for meeting: Meeting) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HHmmss"
        let datePart = formatter.string(from: meeting.startedAt)
        let titlePart = sanitize(meeting.title)
        let idPart = meeting.id.uuidString.prefix(8).lowercased()
        return "\(datePart) - \(titlePart) - \(idPart)"
    }

    static func renderMarkdown(_ meeting: Meeting) -> String {
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

    static func encodeJSON(_ meeting: Meeting) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(meeting)
    }

    private static func sanitize(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = trimmed.replacingOccurrences(
            of: #"[\/:*?"<>|]"#,
            with: "-",
            options: .regularExpression
        )
        return cleaned.isEmpty ? "Untitled" : String(cleaned.prefix(80))
    }

    static func yamlEscape(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }
}
