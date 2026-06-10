import Foundation

/// Pure helpers that turn raw transcript segments into readable, Gemini-style prose:
/// per-speaker merged paragraphs grouped under periodic timestamp section headers.
enum TranscriptFormatter {
    /// Consecutive same-speaker segments merged into a single paragraph.
    struct Block: Equatable {
        let speaker: TranscriptSegment.Speaker
        /// Diarization label ("A"/"B") carried from the constituent segments; nil when unknown.
        let diarizedSpeaker: String?
        let text: String
        /// Start of the first constituent segment.
        let startedAt: TimeInterval
        /// End of the last constituent segment.
        let endedAt: TimeInterval
        /// True when any constituent segment was non-final.
        let isPartial: Bool
    }

    /// A group of blocks rendered under one `### MM:SS` header.
    struct Section: Equatable {
        /// Start of the section's first block; this is the header timestamp.
        let startedAt: TimeInterval
        let blocks: [Block]
    }

    /// Merges consecutive segments by the same speaker into paragraph blocks. A new block
    /// starts when the speaker changes, the diarized speaker label changes (nil == nil
    /// counts as the same), or the silence gap exceeds `gapThreshold`.
    static func mergedBlocks(
        _ segments: [TranscriptSegment],
        gapThreshold: TimeInterval = 10
    ) -> [Block] {
        var blocks: [Block] = []
        for segment in segments {
            if let last = blocks.last,
               last.speaker == segment.speaker,
               last.diarizedSpeaker == segment.diarizedSpeaker,
               segment.startedAt - last.endedAt <= gapThreshold {
                blocks[blocks.count - 1] = Block(
                    speaker: last.speaker,
                    diarizedSpeaker: last.diarizedSpeaker,
                    text: last.text + " " + segment.text,
                    startedAt: last.startedAt,
                    endedAt: max(last.endedAt, segment.endedAt),
                    isPartial: last.isPartial || !segment.isFinal
                )
            } else {
                blocks.append(Block(
                    speaker: segment.speaker,
                    diarizedSpeaker: segment.diarizedSpeaker,
                    text: segment.text,
                    startedAt: segment.startedAt,
                    endedAt: segment.endedAt,
                    isPartial: !segment.isFinal
                ))
            }
        }
        return blocks
    }

    /// Groups blocks under section start timestamps. A new section starts when a block
    /// begins at least `interval` seconds after the current section's start.
    static func sections(
        _ blocks: [Block],
        interval: TimeInterval = 75
    ) -> [Section] {
        var sections: [Section] = []
        for block in blocks {
            if let current = sections.last, block.startedAt - current.startedAt < interval {
                sections[sections.count - 1] = Section(
                    startedAt: current.startedAt,
                    blocks: current.blocks + [block]
                )
            } else {
                sections.append(Section(startedAt: block.startedAt, blocks: [block]))
            }
        }
        return sections
    }

    /// Resolves a speaker to the display name used in rendered transcripts.
    ///
    /// For `.others`: a known counterpart name (1:1 meetings) always wins; otherwise a
    /// diarization label renders as "Speaker A"-style; otherwise the generic "Others".
    static func displayName(
        for speaker: TranscriptSegment.Speaker,
        selfName: String?,
        othersName: String?,
        diarizedSpeaker: String? = nil
    ) -> String {
        switch speaker {
        case .you:
            return selfName ?? "You"
        case .others:
            if let othersName { return othersName }
            if let diarizedSpeaker { return "Speaker \(diarizedSpeaker)" }
            return "Others"
        case .named(let name):
            return name
        }
    }

    /// Formats a transcript offset as `MM:SS`, or `H:MM:SS` past one hour.
    static func timestampString(_ time: TimeInterval) -> String {
        let total = max(0, Int(time))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// The `### MM:SS` header timestamp a given segment time falls under: the latest section
    /// starting at or before `time` (or the first section for times before any section).
    /// Deterministic so summary citations can link to existing transcript headers.
    static func sectionTimestamp(for time: TimeInterval, in sections: [Section]) -> String? {
        guard let first = sections.first else { return nil }
        let containing = sections.last(where: { $0.startedAt <= time }) ?? first
        return timestampString(containing.startedAt)
    }

    /// Turns a raw calendar attendee value into a presentable name. Full display names are
    /// returned as-is; bare emails become a capitalized local part
    /// ("michael@linktr.ee" → "Michael", "jane.doe@x.com" → "Jane Doe").
    static func attendeeDisplayName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("@"), !trimmed.contains(" ") else { return trimmed }
        let localPart = trimmed.split(separator: "@").first.map(String.init) ?? trimmed
        let words = localPart
            .components(separatedBy: CharacterSet(charactersIn: "._-+"))
            .filter { !$0.isEmpty }
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
        return words.isEmpty ? trimmed : words.joined(separator: " ")
    }
}
