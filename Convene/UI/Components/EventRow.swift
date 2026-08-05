import SwiftUI

/// Where a calendar event sits relative to now, driving the schedule row's styling.
enum EventStatus {
    case past, current, upcoming
}

struct EventRow: View {
    let event: MeetingEvent
    let status: EventStatus
    let now: Date
    let canJoin: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                StatusCircle(status: status, color: tint)
                timeRange
                    .font(.menuInfo.monospacedDigit())
                Text(event.title)
                    .font(.menuRow.weight(.medium))
                    .foregroundStyle(status == .past ? Color.secondary : Color.primary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                trailing
            }
            .frame(height: 22)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                rowBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeInOut(duration: 0.12), value: hovering)
        .opacity(status == .past ? 0.65 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint(canJoin ? "Joins and records the meeting" : "Starts recording this meeting")
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var trailing: some View {
        if hovering && canJoin {
            Text("Join")
                .font(.pillLabel.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.accent))
                .fixedSize()
        } else if let label = relativeLabel {
            Text(label)
                .font(.pillLabel.weight(.semibold))
                .foregroundStyle(status == .current ? Color.white : Color.accentOnSoft)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Capsule().fill(status == .current ? Color.accent : Color.accentSoft))
                .fixedSize()
        } else if event.attendees.count >= 1 {
            HStack(spacing: 3) {
                Image(systemName: "person")
                    .font(.system(size: 10))
                Text("\(event.attendees.count)")
                    .font(.pillLabel.monospacedDigit())
            }
            .foregroundStyle(.secondary)
        }
    }

    /// Glanceable countdown like Granola/Raycast: "Now" while in progress, "in Xm" for
    /// events starting within the hour. Nil otherwise so the row falls back to attendees.
    private var relativeLabel: String? {
        switch status {
        case .current:
            return "Now"
        case .upcoming:
            let minutes = Int(ceil(event.startDate.timeIntervalSince(now) / 60))
            return (1...60).contains(minutes) ? "in \(minutes)m" : nil
        case .past:
            return nil
        }
    }

    private var accessibilityDescription: String {
        let timeRange = "\(formatted(event.startDate)) to \(formatted(event.endDate))"
        let attendees = event.attendees.count >= 1 ? ", \(event.attendees.count) attendees" : ""
        let statusWord: String
        switch status {
        case .past: statusWord = "past"
        case .current: statusWord = "in progress"
        case .upcoming: statusWord = "upcoming"
        }
        return "\(event.title), \(timeRange), \(statusWord)\(attendees)"
    }

    private var rowBackground: Color {
        if status == .current { return Color.accentSoft }
        if hovering { return Color.hoverBackground }
        return .clear
    }

    private var timeRange: Text {
        // Quiet metadata: the title is the row's anchor, so the time recedes.
        Text(formatted(event.startDate)).foregroundColor(.secondary)
            + Text(" – \(formatted(event.endDate))").foregroundColor(Color.textTertiary)
    }

    private func formatted(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    private var tint: Color {
        if let nsColor = event.calendarColor {
            return Color(nsColor)
        }
        return Color.accent
    }
}
