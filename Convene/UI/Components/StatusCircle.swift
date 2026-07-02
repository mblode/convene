import SwiftUI

/// The leading indicator in a schedule row: a filled check for past events, a ringed dot for
/// the current one, and a hollow ring for upcoming events.
struct StatusCircle: View {
    let status: EventStatus
    let color: Color

    var body: some View {
        ZStack {
            switch status {
            case .past:
                Circle().fill(color.opacity(0.18))
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(color)
            case .current:
                Circle().stroke(color, lineWidth: 2)
                Circle().fill(color).frame(width: 5, height: 5)
            case .upcoming:
                Circle().stroke(color, lineWidth: 1.5)
            }
        }
        .frame(width: 14, height: 14)
    }
}
