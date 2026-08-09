import SwiftUI

/// The one screen shown on a first launch, before the meetings list.
///
/// Deliberately a single screen rather than a paged tour. Everything worth saying here is three
/// short facts, and the honest reason a tour exists — to make setup feel shorter than it is — is
/// answered better by `SetupChecklist`, which stays on the root screen until the work is actually
/// done. Nothing on this screen is a step; it is the paragraph you read before you begin.
///
/// The caller owns the flag: read `OnboardingDefaults.hasSeenWelcomeKey` with `@AppStorage` and set
/// it from `onGetStarted`, so the value that controls presentation is the same one that records it.
struct WelcomeView: View {
    let onGetStarted: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MobileTheme.Spacing.xxl) {
                lede
                points
            }
            .padding(.horizontal, MobileTheme.Spacing.xl)
            .padding(.top, MobileTheme.Spacing.xxl)
            .padding(.bottom, MobileTheme.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.appBackground)
        // Pinned rather than placed at the end of the scroll: at an accessibility text size the
        // three points run well past a screen, and a "Get started" the user has to scroll to find
        // is the one control on this screen that must never be hard to reach.
        .safeAreaInset(edge: .bottom) { getStarted }
    }

    private var lede: some View {
        VStack(alignment: .leading, spacing: MobileTheme.Spacing.md) {
            Text("Convene")
                .typeStyle(.display)
                .foregroundStyle(Color.textPrimary)

            Text(
                "Record a meeting on your iPhone. Convene transcribes it as it goes, writes a summary when you stop, and saves the lot as a markdown file you own."
            )
            .typeStyle(.body)
            .foregroundStyle(Color.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var points: some View {
        VStack(alignment: .leading, spacing: MobileTheme.Spacing.xl) {
            WelcomePoint(
                systemImage: "waveform",
                title: "One microphone, one tap",
                detail:
                    "Everyone in the room arrives on the same stream, and the transcript separates the speakers as it builds."
            )

            WelcomePoint(
                systemImage: "folder",
                title: "Notes land in your own folder",
                detail:
                    "Every meeting saves as a markdown file. Point Convene at your Obsidian vault and notes sync to the same vault on your Mac, or leave it alone and they stay in Convene’s own folder, under On My iPhone in Files."
            )

            WelcomePoint(
                systemImage: "lock",
                title: "Your keys, and no middleman",
                detail:
                    "Keys live in your iPhone’s Keychain. There’s no Convene server — audio goes to AssemblyAI, the transcript goes to your summary provider, and nowhere else."
            )
        }
    }

    private var getStarted: some View {
        VStack(spacing: MobileTheme.Spacing.md) {
            Text("Setting up takes a minute: an AssemblyAI key, and the microphone when you first record.")
                .typeStyle(.caption)
                .foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)

            Button(action: onGetStarted) {
                Text("Get started")
                    .typeStyle(.bodyEmphasis)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .glassActionButton(isProminent: true)
            .tint(Color.accent)
        }
        .padding(.horizontal, MobileTheme.Spacing.xl)
        .padding(.top, MobileTheme.Spacing.lg)
        .padding(.bottom, MobileTheme.Spacing.sm)
        .background(Color.appBackground)
    }
}

private struct WelcomePoint: View {
    let systemImage: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: MobileTheme.Spacing.md) {
            // Symbols, not illustrations: they mark where each point starts when the eye is
            // scanning, and carry nothing that the words beside them don't already say — which is
            // why they're hidden from VoiceOver rather than labelled.
            Image(systemName: systemImage)
                .imageScale(.medium)
                .foregroundStyle(Color.accent)
                .frame(width: 22)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: MobileTheme.Spacing.xs) {
                Text(title)
                    .typeStyle(.bodyEmphasis)
                    .foregroundStyle(Color.textPrimary)

                Text(detail)
                    .typeStyle(.body)
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
