import SwiftUI

/// The app's primary action, floating above the meetings list.
///
/// One control in two states rather than two controls that swap places. Idle it is a "Record"
/// capsule; live it is the same capsule, in the same spot, showing the level meter and the running
/// time. Keeping it a single button — one shape, one layer, contents mutating inside it — is what
/// makes starting a meeting and coming back to one feel like the same object, and it means a
/// running meeting is always exactly where the user last put their thumb.
///
/// It is Liquid Glass on iOS 26 and later, which is the whole reason it can float over the list
/// without a shadow doing the separating.
struct RecordFAB: View {
    let isRecording: Bool
    let isBusy: Bool
    let isInterrupted: Bool
    let startedAt: Date?
    /// Passed through rather than observed: `LevelMeter` does the observing, so a level update at
    /// ~45Hz redraws five capsules instead of the whole control.
    let levelMeter: InputLevelMeter
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Grows with the user's text size rather than staying a 56pt pill under 40pt digits.
    @ScaledMetric(relativeTo: .body) private var minHeight: CGFloat = 56

    private var tint: Color { isRecording ? .recordingRed : .accent }

    var body: some View {
        let button = Button(action: action) {
            content
                .foregroundStyle(tint)
                .padding(.horizontal, MobileTheme.Spacing.xl)
                .frame(minHeight: minHeight)
                .controlGlass(tint: tint, in: .capsule)
                .contentShape(.capsule)
                .animation(reduceMotion ? nil : MobileTheme.Motion.standard, value: isRecording)
        }
        .buttonStyle(FloatingControlPressStyle())
        .disabled(isBusy)
        .accessibilityHint(
            isRecording ? "Opens the recording controls" : "Starts recording and opens the controls"
        )

        if #available(iOS 26.0, *) {
            GlassEffectContainer { button }
        } else {
            button
        }
    }

    @ViewBuilder
    private var content: some View {
        HStack(spacing: MobileTheme.Spacing.sm) {
            if isBusy {
                ProgressView()
                    .tint(tint)
                    .accessibilityLabel(isRecording ? "Stopping" : "Starting")
            } else if isRecording {
                // No separate blinking dot: the meter is already the live indicator, and a better
                // one, because it distinguishes "recording and hearing the room" from "recording
                // silence" — which a dot on a timer cannot.
                LevelMeter(
                    meter: levelMeter,
                    isActive: !isInterrupted,
                    tint: tint,
                    size: .compact
                )
                ElapsedTimeText(startedAt: startedAt)
                    .typeStyle(.mono)
            } else {
                Image(systemName: "record.circle.fill")
                    .imageScale(.large)
                Text("Record")
                    .typeStyle(.bodyEmphasis)
            }
        }
        .transition(.opacity)
    }
}

/// The elapsed time, ticking on its own schedule.
///
/// A `TimelineView` rather than a `Timer.publish` on the enclosing screen: the timeline redraws
/// these digits and nothing else, where a published tick re-rendered the whole recording view —
/// transcript included — once a second for a clock in the corner. It also stops on its own when the
/// view goes off-screen, so "only tick while recording" stops being something a caller has to
/// remember.
///
/// The schedule is anchored to `startedAt`, so the digits flip on the meeting's own second
/// boundaries instead of drifting a fraction behind them.
struct ElapsedTimeText: View {
    let startedAt: Date?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: startedAt ?? .now, by: 1)) { context in
            let text = TranscriptFormatter.timestampString(
                startedAt.map { max(0, context.date.timeIntervalSince($0)) } ?? 0
            )

            Text(text)
                .contentTransition(.numericText())
                .animation(reduceMotion ? nil : MobileTheme.Motion.quiet, value: text)
                .accessibilityLabel("Recording, \(text) elapsed")
        }
    }
}

/// Press feedback for the app's floating glass controls.
///
/// On iOS 26 the interactive glass effect already flexes under the finger, so this stays out of the
/// way and only supplies the scale on older releases — doubling the two would read as the control
/// shrinking twice for one press.
struct FloatingControlPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let usesGlassPressResponse: Bool = {
            if #available(iOS 26.0, *) { return true }
            return false
        }()

        return configuration.label
            .scaleEffect(configuration.isPressed && !usesGlassPressResponse ? 0.96 : 1)
            .animation(
                reduceMotion ? nil : .spring(duration: 0.25, bounce: 0),
                value: configuration.isPressed
            )
    }
}
