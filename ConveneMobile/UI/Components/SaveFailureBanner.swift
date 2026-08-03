import SwiftUI

/// A meeting that finished but could not be written to disk, and the way back from it.
///
/// This is the only error in the app holding something that cannot be recreated: the room has gone
/// home, the transcript exists in memory and in the write-ahead log, and the folder it was headed
/// for refused it — usually a vault that iCloud has not brought back yet, or a security-scoped
/// bookmark that went stale while the phone was locked. Those all clear on their own, which is
/// exactly why a plain error message was the wrong answer: the fix is to try again in a moment, and
/// until now there was no way to ask.
///
/// Louder than `BannerView` on purpose. The rest of the app's notices are things you may read;
/// this one you have to answer.
struct SaveFailureBanner: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MobileTheme.Spacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: MobileTheme.Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .imageScale(.small)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: MobileTheme.Spacing.xs) {
                    Text("This meeting hasn’t been saved")
                        .typeStyle(.bodyEmphasis)
                        .foregroundStyle(Color.textPrimary)

                    Text(message)
                        .typeStyle(.caption)
                        .foregroundStyle(Color.textSecondary)

                    // Said plainly because the obvious fear is the wrong one. Nothing has been
                    // thrown away — the recording is still held, and retrying costs nothing.
                    Text("Nothing has been lost. Convene is still holding it.")
                        .typeStyle(.caption)
                        .foregroundStyle(Color.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .foregroundStyle(Color.recordingRed)

            Button("Try saving again", action: retry)
                .typeStyle(.bodyEmphasis)
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, MobileTheme.Spacing.lg)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color.chipBackground, in: Capsule())
                .buttonStyle(PressableStyle())
        }
        .padding(MobileTheme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.recordingRed.opacity(0.1),
            in: RoundedRectangle(cornerRadius: MobileTheme.Radius.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: MobileTheme.Radius.card)
                .strokeBorder(Color.recordingRed.opacity(0.3), lineWidth: 1)
        )
        // Grouped so VoiceOver reads the problem and the reassurance as one statement, then finds
        // the button as the single thing to act on.
        .accessibilityElement(children: .contain)
    }
}
