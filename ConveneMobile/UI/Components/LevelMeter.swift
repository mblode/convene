import SwiftUI

/// A row of bars that lights up with the room's volume.
///
/// This is the answer to the only question that matters when a phone is face down on a table: is
/// this thing actually hearing us? A meter on a timer would look the same whether the room were
/// talking or the microphone were dead, so it reads the real input level instead.
///
/// It inherits two properties from the halo that used to ring the record button. The level rides on
/// top of a floor rather than starting at zero, so a quiet room still reads as "listening" and not
/// as a stopped recording. And there is no animation modifier anywhere below: the meter's own
/// attack/release envelope is the smoothing, and a spring here would lag the room by its own settle
/// time and turn a live reading into an echo of one.
///
/// Nothing in it moves — the bars are fixed geometry and only their fill changes — so it is already
/// the form the halo degraded to under Reduce Motion, and needs no branch for it.
struct LevelMeter: View {
    enum Size {
        /// Inside the record pill, beside the elapsed time.
        case compact
        /// Under the timer in the recording sheet, where the meter is the whole readout.
        case expanded
    }

    @ObservedObject var meter: InputLevelMeter
    /// False while interrupted or idle: the bars fall back to their unlit rest state rather than
    /// freezing at whatever the last sample was.
    var isActive: Bool
    var tint: Color
    var size: Size

    // Scaled so the meter grows with the user's text size instead of staying a 26pt strip beside
    // 40pt digits. Bar width and gap are derived from the height, so one metric per size is enough.
    @ScaledMetric(relativeTo: .body) private var compactHeight: CGFloat = 14
    @ScaledMetric(relativeTo: .body) private var expandedHeight: CGFloat = 28

    /// The lit fraction at silence. Enough to read as a live meter, little enough that the first
    /// syllable still visibly moves it.
    private let floor: Double = 0.1

    var body: some View {
        HStack(spacing: gap) {
            ForEach(0..<barCount, id: \.self) { index in
                Capsule()
                    .fill(tint.opacity(0.16 + fill(index) * 0.84))
                    .frame(width: barWidth, height: height)
            }
        }
        // VoiceOver cannot watch a meter that redraws forty times a second; the elapsed readout
        // beside it carries "this is recording" in a form that can actually be spoken.
        .accessibilityHidden(true)
    }

    /// How lit bar `index` is, 0...1.
    ///
    /// The leading bar fades in rather than snapping on. A hard threshold per bar turns a rising
    /// voice into a staircase and makes the meter twitch between two bars on a steady one.
    private func fill(_ index: Int) -> Double {
        guard isActive else { return 0 }
        let lit = (floor + Double(meter.level) * (1 - floor)) * Double(barCount)
        return min(max(lit - Double(index), 0), 1)
    }

    private var barCount: Int {
        size == .compact ? 5 : 12
    }

    private var height: CGFloat {
        size == .compact ? compactHeight : expandedHeight
    }

    private var barWidth: CGFloat { height * 0.3 }
    private var gap: CGFloat { height * 0.24 }
}
