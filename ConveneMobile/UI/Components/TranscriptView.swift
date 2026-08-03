import SwiftUI

/// Transcript segments as merged per-speaker paragraphs — the same shape the saved markdown uses,
/// so a transcript looks the same live as it does once it's on disk.
struct TranscriptView: View {
    let segments: [TranscriptSegment]
    var selfName: String?
    var othersName: String?

    private var blocks: [TranscriptFormatter.Block] {
        TranscriptFormatter.mergedBlocks(segments)
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: MobileTheme.Spacing.lg) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                VStack(alignment: .leading, spacing: MobileTheme.Spacing.xs) {
                    HStack(spacing: MobileTheme.Spacing.sm) {
                        Text(
                            TranscriptFormatter.displayName(
                                for: block.speaker,
                                selfName: selfName,
                                othersName: othersName,
                                diarizedSpeaker: block.diarizedSpeaker
                            )
                        )
                        .typeStyle(.section)
                        .foregroundStyle(Color.textPrimary)

                        Text(TranscriptFormatter.timestampString(block.startedAt))
                            .typeStyle(.mono)
                            .foregroundStyle(Color.textSecondary)
                    }

                    Text(block.text)
                        .typeStyle(.body)
                        // Partial turns are still being revised by the transcriber. Dimming them
                        // keeps a rewrite from reading as text being deleted.
                        .foregroundStyle(block.isPartial ? Color.textSecondary : Color.textPrimary)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                // One turn, one element. Read segment by segment, a transcript makes VoiceOver
                // announce the speaker's name and the timestamp as two separate stops before every
                // paragraph, which is unusable at the length these run to.
                .accessibilityElement(children: .combine)
            }
        }
    }
}
