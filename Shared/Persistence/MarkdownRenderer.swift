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
        let isoFormatter = ISO8601DateFormatter()
        let isoStart = isoFormatter.string(from: meeting.startedAt)
        let durationSeconds: Int = {
            guard let end = meeting.endedAt else { return 0 }
            return max(0, Int(ceil(end.timeIntervalSince(meeting.startedAt))))
        }()
        let durationMinutes: Int = {
            guard durationSeconds > 0 else { return 0 }
            return max(1, Int(ceil(Double(durationSeconds) / 60.0)))
        }()
        let transcriptSegments = meeting.transcript
            .removingLikelyEchoDuplicates()
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        var out = ""
        out += "---\n"
        out += "title: \(yamlEscape(meeting.title))\n"
        out += "type: meeting\n"
        out += "status: raw\n"
        out += "source: convene\n"
        out += "meeting_id: \(yamlEscape(meeting.id.uuidString.lowercased()))\n"
        out += "date: \(isoStart)\n"
        out += "started_at: \(isoStart)\n"
        if let endedAt = meeting.endedAt {
            out += "ended_at: \(isoFormatter.string(from: endedAt))\n"
        }
        out += "duration_seconds: \(durationSeconds)\n"
        out += "duration_minutes: \(durationMinutes)\n"
        out += "transcript_segments: \(transcriptSegments.count)\n"
        out += "tags:\n"
        out += "  - meeting\n"
        out += "  - convene\n"
        if !meeting.attendees.isEmpty {
            out += "attendees:\n"
            for attendee in meeting.attendees {
                out += "  - \(yamlEscape(attendee))\n"
            }
        }
        if let summary = meeting.summary {
            out += "summary_generated_at: \(isoFormatter.string(from: summary.generatedAt))\n"
            if let provider = summary.provider {
                out += "summary_provider: \(yamlEscape(provider))\n"
            }
            if let model = summary.model {
                out += "summary_model: \(yamlEscape(model))\n"
            }
            if let promptVersion = summary.promptVersion {
                out += "summary_prompt_version: \(yamlEscape(promptVersion))\n"
            }
        }
        if let audio = meeting.audioFilename {
            out += "audio: \(yamlEscape(audio))\n"
        }
        out += "---\n\n"

        out += "# \(meeting.title)\n\n"

        if let summary = meeting.summary {
            out += "## TL;DR\n\n"
            out += cleanParagraphs(summary.overview)
            out += "\n\n"

            appendBullets(title: "Topics", items: summary.topics, to: &out)
            if !summary.keyPoints.isEmpty {
                appendBullets(title: "Key Points", items: summary.keyPoints, to: &out)
            }
            appendBullets(title: "Decisions", items: summary.decisions, to: &out, emptyText: "None captured.")
            appendChecklist(title: "Action Items", items: summary.actionItems, to: &out, emptyText: "None captured.")
            appendBullets(title: "Open Questions", items: summary.openQuestions, to: &out, emptyText: "None captured.")
            appendBullets(title: "Follow-ups", items: summary.followUps, to: &out)
        }

        if !meeting.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            out += "## Participant Notes\n\n"
            out += meeting.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            out += "\n\n"
        }

        if let transcriptionError = meeting.transcriptionError?.trimmingCharacters(in: .whitespacesAndNewlines),
           !transcriptionError.isEmpty {
            out += "## Transcription Error\n\n"
            out += transcriptionError
            out += "\n\n"
        }

        if !transcriptSegments.isEmpty {
            out += "## Transcript\n\n"
            for segment in transcriptSegments {
                let mm = Int(segment.startedAt) / 60
                let ss = Int(segment.startedAt) % 60
                let stamp = String(format: "%02d:%02d", mm, ss)
                let finalMarker = segment.isFinal ? "" : " _(partial)_"
                out += "**\(segment.speaker.displayName) [\(stamp)]:**\(finalMarker) \(cleanInline(segment.text))\n\n"
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

    private static func appendBullets(
        title: String,
        items: [String],
        to out: inout String,
        emptyText: String? = nil
    ) {
        let cleaned = items.map(cleanInline).filter { !$0.isEmpty }
        guard !cleaned.isEmpty else {
            if let emptyText {
                out += "## \(title)\n\n"
                out += "\(emptyText)\n\n"
            }
            return
        }

        out += "## \(title)\n\n"
        for item in cleaned {
            out += "- \(item)\n"
        }
        out += "\n"
    }

    private static func appendChecklist(
        title: String,
        items: [String],
        to out: inout String,
        emptyText: String? = nil
    ) {
        let cleaned = items.map(cleanInline).filter { !$0.isEmpty }
        guard !cleaned.isEmpty else {
            if let emptyText {
                out += "## \(title)\n\n"
                out += "\(emptyText)\n\n"
            }
            return
        }

        out += "## \(title)\n\n"
        for item in cleaned {
            out += "- [ ] \(item)\n"
        }
        out += "\n"
    }

    private static func cleanParagraphs(_ value: String) -> String {
        let paragraphs = value
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return paragraphs.joined(separator: "\n\n")
    }

    private static func cleanInline(_ value: String) -> String {
        let flattened = value
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(
                of: #"^\s*(?:[-*•]+|\d+[.)]|\[[ xX]\])\s*"#,
                with: "",
                options: .regularExpression
            )
        return flattened
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
