import SwiftUI

/// What a note shows where the summary goes, when there isn't a summary to show.
///
/// A meeting is saved the moment it ends and its summary arrives seconds later, so `Meeting.summary`
/// being `nil` means three different things to the user. Naming them lets the note say which.
enum SummaryStatus: Equatable {
    /// Summaries are turned off, or this meeting predates them. Renders nothing: a summary the
    /// user never asked for is missing on purpose, not broken.
    case off
    /// Saved, and the summary is still being written.
    case pending
    /// The provider's own message, when it gave one.
    case failed(String?)
}

/// The pending and failed halves of a note's summary.
///
/// Both states existed before this view and neither was on screen: a note simply sat empty for the
/// few seconds a summary takes, and stayed empty forever if the call failed.
struct SummaryStatusCard: View {
    let status: SummaryStatus
    /// Supplied by the screen that owns the store. Without it the failed card explains and stops
    /// there, which is the honest thing to show when nothing can act on a tap.
    var retry: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBreathing = false

    @ViewBuilder
    var body: some View {
        switch status {
        case .off:
            EmptyView()
        case .pending:
            pending
        case .failed(let message):
            failure(message)
        }
    }

    private var pending: some View {
        HStack(alignment: .firstTextBaseline, spacing: MobileTheme.Spacing.md) {
            Image(systemName: "pencil")
                .imageScale(.medium)
                .foregroundStyle(Color.accent)

            VStack(alignment: .leading, spacing: MobileTheme.Spacing.xs) {
                Text("Writing notes…")
                    .typeStyle(.bodyEmphasis)
                    .foregroundStyle(Color.textPrimary)
                Text("The summary lands here in a few seconds.")
                    .typeStyle(.caption)
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer(minLength: 0)
        }
        // One slow fade on the contents, with the card itself held still. A spinner or a bank of
        // shimmering skeleton bars would claim the summary is nearly here; it might be, or the
        // model might be thinking for another twenty seconds. Breathing says "working" and nothing
        // more, which is all this view actually knows.
        .opacity(isBreathing ? 0.55 : 1)
        .animation(reduceMotion ? nil : breath, value: isBreathing)
        .padding(MobileTheme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
        .onAppear { isBreathing = !reduceMotion }
        .accessibilityElement(children: .combine)
        // VoiceOver re-reads a focused element carrying this trait, so the summary replacing this
        // card is announced instead of silently swapping under the cursor.
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var breath: Animation {
        .easeInOut(duration: 1.8).repeatForever(autoreverses: true)
    }

    private func failure(_ message: String?) -> some View {
        VStack(alignment: .leading, spacing: MobileTheme.Spacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: MobileTheme.Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .imageScale(.small)
                Text("No summary was written")
                    .typeStyle(.bodyEmphasis)
            }
            .foregroundStyle(Color.recordingRed)

            VStack(alignment: .leading, spacing: MobileTheme.Spacing.xs) {
                Text(message ?? "The summary provider didn’t answer.")
                // The transcript and the typed notes are already on disk by the time a summary is
                // attempted, so the one thing worth saying first is that nothing was lost.
                Text("Your transcript and notes are saved either way.")
            }
            .typeStyle(.caption)
            .foregroundStyle(Color.textSecondary)
            .textSelection(.enabled)

            if let retry {
                ChipButton(text: "Try again", systemImage: "arrow.clockwise", action: retry)
                    .padding(.top, MobileTheme.Spacing.xs)
            }
        }
        .padding(MobileTheme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }
}
