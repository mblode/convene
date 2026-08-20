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
        // Compute the transcript sections once so summary citations always link to
        // the exact `### MM:SS` headers this renderer emits below.
        let transcriptBlocks = TranscriptFormatter.mergedBlocks(transcriptSegments)
        let transcriptSections = TranscriptFormatter.sections(transcriptBlocks)
        let transcriptEnd = transcriptBlocks.map(\.endedAt).max() ?? 0
        let keyMoments = meeting.keyMoments.sorted { $0.offset < $1.offset }

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
            let displayNames = meeting.attendees.map(TranscriptFormatter.attendeeDisplayName)
            out += "attendees:\n"
            for name in displayNames {
                out += "  - \(yamlEscape(name))\n"
            }
            if displayNames != meeting.attendees {
                out += "attendee_emails:\n"
                for attendee in meeting.attendees {
                    out += "  - \(yamlEscape(attendee))\n"
                }
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

        appendKeyMomentsIndex(
            keyMoments,
            sections: transcriptSections,
            transcriptEnd: transcriptEnd,
            to: &out
        )

        if let summary = meeting.summary {
            out += "## TL;DR\n\n"
            out += cleanParagraphs(summary.overview)
            out += "\n\n"

            appendDetails(
                summary.details,
                sections: transcriptSections,
                transcriptEnd: transcriptEnd,
                to: &out
            )
            appendBullets(title: "Topics", items: summary.topics, to: &out)
            if !summary.keyPoints.isEmpty {
                appendBullets(title: "Key Points", items: summary.keyPoints, to: &out)
            }
            appendBullets(title: "Decisions", items: summary.decisions, to: &out, emptyText: "None captured.")
            appendChecklist(
                title: "Action Items", items: summary.actionItems, to: &out, emptyText: "None captured.")
            appendBullets(
                title: "Open Questions", items: summary.openQuestions, to: &out, emptyText: "None captured.")
            appendBullets(title: "Follow-ups", items: summary.followUps, to: &out)
        }

        if !meeting.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            out += "## Participant Notes\n\n"
            out += meeting.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            out += "\n\n"
        }

        if let transcriptionError = meeting.transcriptionError?.trimmingCharacters(
            in: .whitespacesAndNewlines),
            !transcriptionError.isEmpty
        {
            out += "## Transcription Error\n\n"
            out += transcriptionError
            out += "\n\n"
        }

        if !transcriptSegments.isEmpty {
            out += "## Transcript\n\n"
            // Walk key moments in lockstep with the blocks so each flag lands inline at the
            // spot it was dropped.
            var momentIndex = 0
            for section in transcriptSections {
                out += "### \(TranscriptFormatter.timestampString(section.startedAt))\n\n"
                for block in section.blocks {
                    while momentIndex < keyMoments.count,
                        keyMoments[momentIndex].offset <= block.startedAt
                    {
                        out += inlineKeyMomentMarker(keyMoments[momentIndex])
                        momentIndex += 1
                    }
                    let name = TranscriptFormatter.displayName(
                        for: block.speaker,
                        selfName: meeting.selfName,
                        othersName: meeting.othersName,
                        diarizedSpeaker: block.diarizedSpeaker
                    )
                    let partialMarker = block.isPartial ? " _(partial)_" : ""
                    out += "**\(name):**\(partialMarker) \(cleanInline(block.text))\n\n"
                }
            }
            // Any moments flagged after the last transcribed block.
            while momentIndex < keyMoments.count {
                out += inlineKeyMomentMarker(keyMoments[momentIndex])
                momentIndex += 1
            }
        }

        return out
    }

    /// Renders the "## Key Moments" index near the top: one bullet per flag, linking to the
    /// transcript section it falls under. Omitted entirely when there are no moments.
    private static func appendKeyMomentsIndex(
        _ moments: [KeyMoment],
        sections: [TranscriptFormatter.Section],
        transcriptEnd: TimeInterval,
        to out: inout String
    ) {
        guard !moments.isEmpty else { return }
        out += "## Key Moments\n\n"
        for moment in moments {
            let link = keyMomentLink(
                offset: moment.offset,
                sections: sections,
                transcriptEnd: transcriptEnd
            )
            let text = cleanInline(moment.text)
            out += text.isEmpty ? "- \(link)\n" : "- \(link) — \(text)\n"
        }
        out += "\n"
    }

    /// A blockquote marker dropped inline in the transcript at a flagged moment.
    private static func inlineKeyMomentMarker(_ moment: KeyMoment) -> String {
        let stamp = TranscriptFormatter.timestampString(moment.offset)
        let text = cleanInline(moment.text)
        return text.isEmpty
            ? "> ⭐ **Key moment** (\(stamp))\n\n"
            : "> ⭐ **Key moment** (\(stamp)) — \(text)\n\n"
    }

    /// Wikilink from a key-moment offset to the transcript section header it falls under,
    /// mirroring `citation`. Falls back to a plain `MM:SS` label when there's no transcript
    /// to link into (so the index still reads cleanly).
    private static func keyMomentLink(
        offset: TimeInterval,
        sections: [TranscriptFormatter.Section],
        transcriptEnd: TimeInterval
    ) -> String {
        let label = TranscriptFormatter.timestampString(offset)
        guard offset <= transcriptEnd,
            let anchor = TranscriptFormatter.sectionTimestamp(for: offset, in: sections)
        else {
            return label
        }
        return "[[#\(anchor)|\(label)]]"
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
        let escaped =
            value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }

    /// Renders the `## Details` section: one `### {title}` per detail with its narrative
    /// and trailing transcript citations. Omitted entirely when there are no details.
    private static func appendDetails(
        _ details: [SummaryDetail],
        sections: [TranscriptFormatter.Section],
        transcriptEnd: TimeInterval,
        to out: inout String
    ) {
        let cleaned = details.filter {
            !cleanInline($0.title).isEmpty && !cleanInline($0.narrative).isEmpty
        }
        guard !cleaned.isEmpty else { return }

        out += "## Details\n\n"
        for detail in cleaned {
            out += "### \(cleanInline(detail.title))\n\n"
            var paragraph = cleanParagraphs(detail.narrative)
            let citations = detail.timestamps
                .map { citation(for: $0, sections: sections, transcriptEnd: transcriptEnd) }
                .filter { !$0.isEmpty }
            if !citations.isEmpty {
                paragraph += " " + citations.joined(separator: " ")
            }
            out += paragraph
            out += "\n\n"
        }
    }

    /// Maps a cited `MM:SS` timestamp to an Obsidian wikilink targeting the transcript
    /// section header it falls under (`[[#05:00|07:23]]`). Falls back to plain text when
    /// the timestamp can't be parsed or maps outside the transcript — no dead links.
    private static func citation(
        for rawTimestamp: String,
        sections: [TranscriptFormatter.Section],
        transcriptEnd: TimeInterval
    ) -> String {
        let trimmed = rawTimestamp.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        guard let time = parseTimestamp(trimmed),
            time <= transcriptEnd,
            let anchor = TranscriptFormatter.sectionTimestamp(for: time, in: sections)
        else {
            return trimmed
        }
        return "[[#\(anchor)|\(trimmed)]]"
    }

    /// Parses `MM:SS` or `H:MM:SS` back to a transcript offset. Returns nil for garbage.
    private static func parseTimestamp(_ raw: String) -> TimeInterval? {
        let parts = raw.split(separator: ":").map(String.init)
        guard (2...3).contains(parts.count),
            parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) })
        else {
            return nil
        }
        let numbers = parts.compactMap(Int.init)
        guard numbers.count == parts.count else { return nil }
        if numbers.count == 2 {
            guard numbers[1] < 60 else { return nil }
            return TimeInterval(numbers[0] * 60 + numbers[1])
        }
        guard numbers[1] < 60, numbers[2] < 60 else { return nil }
        return TimeInterval(numbers[0] * 3600 + numbers[1] * 60 + numbers[2])
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
        let paragraphs =
            value
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return paragraphs.joined(separator: "\n\n")
    }

    private static func cleanInline(_ value: String) -> String {
        let flattened =
            value
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(
                of: #"^\s*(?:[-*•]+|\d+[.)]|\[[ xX]\])\s*"#,
                with: "",
                options: .regularExpression
            )
        return
            flattened
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
