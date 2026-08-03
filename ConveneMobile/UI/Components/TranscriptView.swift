import SwiftUI

/// Transcript segments as merged per-speaker paragraphs — the same shape the saved markdown uses,
/// so a transcript looks the same live as it does once it's on disk.
struct TranscriptView: View {
    let segments: [TranscriptSegment]
    var selfName: String?
    var othersName: String?

    /// Merged once per change of `segments`, not once per render.
    ///
    /// As a computed property this re-walked the entire transcript inside `body` — and the
    /// recording sheet re-renders on every keystroke in the notes field, because the notes and the
    /// segments live on the same `ObservableObject`. Typing during a long meeting meant re-merging
    /// the whole transcript per character, on the main thread.
    @State private var blocks: [TranscriptFormatter.Block] = []

    var body: some View {
        LazyVStack(alignment: .leading, spacing: MobileTheme.Spacing.lg) {
            // Keyed by start time, not by position. A block's `startedAt` is fixed when its first
            // segment lands and survives the revisions that follow, where the array index shifts
            // every time a partial turn merges into the block above it — which invalidated every
            // row below the change on each transcript update.
            ForEach(blocks, id: \.startedAt) { block in
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
        .onChange(of: segments, initial: true) { _, latest in
            blocks = TranscriptFormatter.mergedBlocks(latest)
        }
    }
}
