import SwiftUI

/// One saved meeting in the root list: what it was called, when it happened, and — once the
/// summary lands — the first thing it says.
///
/// Everything here is metadata rather than a control, so the card is a single VoiceOver element
/// with a composed label. Read as separate items, three chips would triple the length of a swipe
/// through the list without adding anything the composed label doesn't already say.
struct MeetingCard: View {
    let meeting: Meeting

    var body: some View {
        VStack(alignment: .leading, spacing: MobileTheme.Spacing.md) {
            Text(meeting.title)
                .typeStyle(.cardTitle)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            chips

            if let overview {
                Text(overview)
                    .typeStyle(.body)
                    .foregroundStyle(Color.textTertiary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(MobileTheme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    /// The chip row, or a stack of chips when the row no longer fits.
    ///
    /// Three pills of metadata run past the card's width somewhere around the first accessibility
    /// text size. Truncating them would drop the count that says the meeting has flagged moments in
    /// it, so the row breaks into a column instead and the card simply gets taller.
    private var chips: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: MobileTheme.Spacing.sm) { chipContents }
            VStack(alignment: .leading, spacing: MobileTheme.Spacing.sm) { chipContents }
        }
    }

    @ViewBuilder private var chipContents: some View {
        Chip(text: meeting.startedAt.formatted(date: .omitted, time: .shortened))

        if let duration = durationText(width: .narrow) {
            Chip(text: duration)
        }

        if !meeting.keyMoments.isEmpty {
            Chip(text: "\(meeting.keyMoments.count)", systemImage: "flag.fill")
        }
    }

    private var overview: String? {
        let overview = meeting.summary?.overview.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let overview, !overview.isEmpty else { return nil }
        return overview
    }

    /// `nil` while a meeting is unfinished, or when it was too short to round to a minute — a chip
    /// reading "0m" says less than no chip at all.
    private func durationText(width: Duration.UnitsFormatStyle.UnitWidth) -> String? {
        guard let endedAt = meeting.endedAt else { return nil }
        let seconds = endedAt.timeIntervalSince(meeting.startedAt)
        guard seconds >= 60 else { return nil }
        return Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes], width: width))
    }

    /// The card as one sentence, in the order the eye reads it. Spoken units are written out —
    /// "42 minutes", not the "42m" the chip shows — because a narrow unit is a typographic
    /// abbreviation, and speech synthesis reads it as a letter.
    private var accessibilityLabel: String {
        var parts = [meeting.title, meeting.startedAt.formatted(date: .abbreviated, time: .shortened)]
        if let duration = durationText(width: .wide) {
            parts.append(duration)
        }
        if !meeting.keyMoments.isEmpty {
            let count = meeting.keyMoments.count
            parts.append("\(count) key \(count == 1 ? "moment" : "moments")")
        }
        if let overview {
            parts.append(overview)
        }
        return parts.joined(separator: ", ")
    }
}

/// Press feedback for a whole card.
///
/// The same tint `PressableStyle` uses, in the card's shape: that style fills a `Capsule`, which
/// leaves the tint spilling past the fill at a card's corners.
struct MeetingCardButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay {
                if configuration.isPressed {
                    RoundedRectangle(cornerRadius: MobileTheme.Radius.card)
                        .fill(Color.pressedOverlay)
                }
            }
            .animation(reduceMotion ? nil : MobileTheme.Motion.quiet, value: configuration.isPressed)
    }
}
