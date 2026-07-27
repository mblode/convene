import SwiftUI

/// Start/stop, and — while recording — a halo that follows the room's volume.
///
/// The halo is the answer to the only question that matters when a phone is face down on a table:
/// is this thing actually hearing us? A pulse on a timer would look the same whether the room were
/// talking or the mic were dead, so it's driven by the real input level instead.
///
/// The button itself is Liquid Glass on iOS 26 and later. The halo behind it deliberately is not —
/// glass over glass is the one thing the material is never supposed to do, and a tinted circle
/// reads the level far more legibly than a second refracting layer would.
struct RecordButton: View {
    let isRecording: Bool
    let isBusy: Bool
    let isInterrupted: Bool
    @ObservedObject var levelMeter: InputLevelMeter
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Scaled so the control grows with the user's text size instead of staying an 88pt circle
    // beside 30pt text.
    @ScaledMetric(relativeTo: .largeTitle) private var diameter: CGFloat = 88
    @ScaledMetric(relativeTo: .largeTitle) private var glyphSize: CGFloat = 32

    private var tint: Color { isRecording ? .recordingRed : .accentColor }

    /// The ring sits proud of the button even at silence — a scale of exactly 1 would hide it
    /// behind the button and leave a quiet room looking like a stopped recording. Level rides on
    /// top of that baseline, so the ring reads as "listening" first and "hearing you" second.
    private let haloBaseline: CGFloat = 1.09

    private var haloScale: CGFloat {
        guard isRecording, !isInterrupted else { return haloBaseline }
        return haloBaseline + CGFloat(levelMeter.level) * 0.34
    }

    /// Under Reduce Motion the ring holds still and shows level as brightness instead. Dropping the
    /// feedback entirely would take away the one cue that says the mic is live; a change in opacity
    /// carries it without anything moving.
    private var haloOpacity: Double {
        guard reduceMotion else { return 0.16 }
        guard isRecording, !isInterrupted else { return 0.10 }
        return 0.10 + Double(levelMeter.level) * 0.16
    }

    var body: some View {
        // The halo sits *outside* the glass rather than behind it. Glass refracts whatever is
        // behind it, and the halo redraws at the audio rate (~45Hz) — putting a saturated,
        // continuously-resizing circle in the glass's backdrop made it resample every frame and
        // smear into colour artefacts. Drawn as a sibling underneath, it composites normally.
        ZStack {
            if isRecording {
                Circle()
                    .fill(tint.opacity(haloOpacity))
                    .frame(width: diameter, height: diameter)
                    .scaleEffect(reduceMotion ? haloBaseline : haloScale)
                    // No animation modifier on purpose: the meter's own attack/release envelope is
                    // the smoothing. A spring here would lag the room by its own settle time and
                    // turn a live reading into an echo of one.
                    .accessibilityHidden(true)
            }

            glassButton
        }
        .disabled(isBusy)
        .animation(reduceMotion ? nil : MobileTheme.Motion.standard, value: isRecording)
        .accessibilityLabel(isRecording ? "Stop recording" : "Start recording")
    }

    /// Wrapped in a `GlassEffectContainer` because that is how custom glass is meant to be used:
    /// the container is what gives the effect a defined region to sample and blend within. Bare
    /// `glassEffect` outside one renders, which is why this was missed, but leaves the sampling
    /// unbounded.
    @ViewBuilder
    private var glassButton: some View {
        let button = Button(action: action) {
            ZStack {
                if isBusy {
                    ProgressView()
                } else {
                    Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: glyphSize))
                        .foregroundStyle(tint)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .frame(width: diameter, height: diameter)
            .controlGlass(tint: tint, in: .circle)
        }
        .buttonStyle(RecordButtonPressStyle())

        if #available(iOS 26.0, *) {
            GlassEffectContainer { button }
        } else {
            button
        }
    }
}

/// Press feedback for the record button.
///
/// On iOS 26 the interactive glass effect already flexes under the finger, so this stays out of the
/// way and only supplies the scale on older releases — doubling the two would read as the control
/// shrinking twice for one press.
struct RecordButtonPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let usesGlassPressResponse: Bool = {
            if #available(iOS 26.0, *) { return true }
            return false
        }()

        return configuration.label
            .scaleEffect(configuration.isPressed && !usesGlassPressResponse ? 0.94 : 1)
            .animation(
                reduceMotion ? nil : .spring(duration: 0.25, bounce: 0),
                value: configuration.isPressed
            )
    }
}
