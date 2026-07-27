import SwiftUI

/// Renders transcript segments as merged per-speaker paragraphs, the same shape the saved
/// markdown uses. Shared by the live recording screen and the saved-meeting detail view so a
/// transcript looks the same before and after it's written to disk.
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
                        Text(TranscriptFormatter.displayName(
                            for: block.speaker,
                            selfName: selfName,
                            othersName: othersName,
                            diarizedSpeaker: block.diarizedSpeaker
                        ))
                        .font(.subheadline.weight(.semibold))

                        Text(TranscriptFormatter.timestampString(block.startedAt))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    Text(block.text)
                        .font(.body)
                        // Partial turns are still being revised by the transcriber; dimming them
                        // keeps the screen from reading as though text is being deleted when a
                        // turn is rewritten.
                        .foregroundStyle(block.isPartial ? .secondary : .primary)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
