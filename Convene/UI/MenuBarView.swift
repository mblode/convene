import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var meetingStore: MeetingStore
    @Environment(\.openWindow) private var openWindow

    @State private var now: Date = Date()
    private let tick = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .frame(width: 520)
        .background(Color.menuBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.menu, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.menu, style: .continuous)
                .strokeBorder(Color.cardBorder, lineWidth: Theme.Stroke.hairline)
        )
        .padding(8)
        .task {
            await meetingStore.calendarService.refreshEvents()
        }
        .onReceive(tick) { now = $0 }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ConveneOpenMeetingWindow"))) { _ in
            openMeetingWindow()
        }
    }

    @ViewBuilder
    private var content: some View {
        if !meetingStore.calendarService.hasAccess {
            noAccessState
        } else {
            header
            DashedDivider().padding(.horizontal, 14)
            greetingBlock
            DashedDivider().padding(.horizontal, 14)
            agenda
            footer
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            statusPill
            Spacer()
            headerButton(
                title: meetingStore.captureCoordinator.isCapturing ? "Stop" : "Record",
                shortcut: "⌥⇧R",
                isPrimary: meetingStore.captureCoordinator.isCapturing,
                action: { meetingStore.toggleRecording() }
            )
            .keyboardShortcut("r", modifiers: [.option, .shift])

            headerButton(
                title: "Meeting",
                shortcut: "⌥⇧M",
                action: { openMeetingWindow() }
            )
            .keyboardShortcut("m", modifiers: [.option, .shift])
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var statusPill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(meetingStore.captureCoordinator.isCapturing ? Color.recordingRed : Color.textTertiary)
                .frame(width: 7, height: 7)
            Text(meetingStore.captureStatus)
                .font(.system(size: 12))
                .foregroundStyle(Color.textSecondary)
                .lineLimit(1)
        }
    }

    private func headerButton(
        title: String,
        shortcut: String,
        isPrimary: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isPrimary ? .white : Color.textPrimary)
                Text(shortcut)
                    .font(.system(size: 10))
                    .foregroundStyle(isPrimary ? Color.white.opacity(0.7) : Color.textTertiary)
                    .monospaced()
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isPrimary ? Color.accentOlive : Color.iconBadgeBackground)
        )
    }

    // MARK: - Greeting

    private var greetingBlock: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(greetingTitle(for: now))!")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                summarySentence
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if let next = nextUpcomingEvent() {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Next up")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textTertiary)
                        .textCase(.uppercase)
                    nextUpSentence(next)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: 240, alignment: .leading)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var summarySentence: Text {
        let total = meetingStore.calendarService.todaysEvents.count
        let upcoming = meetingStore.calendarService.todaysEvents.filter { $0.startDate > now }.count

        if total == 0 {
            return Text("You have ")
                + Text("no events").fontWeight(.semibold)
                + Text(" planned for today.")
        }

        let totalText = Text("\(numberWord(total)) event\(total == 1 ? "" : "s")").fontWeight(.semibold)
        let upcomingText = Text("\(numberWord(upcoming)) event\(upcoming == 1 ? "" : "s")").fontWeight(.semibold)

        return Text("You have ")
            + totalText
            + Text(" planned for today and ")
            + upcomingText
            + Text(" \(upcoming == 1 ? "is" : "are") upcoming.")
    }

    private func nextUpSentence(_ event: MeetingEvent) -> Text {
        Text(event.title).fontWeight(.semibold)
            + Text("  starts in ")
            + Text(relativeStart(event.startDate)).fontWeight(.semibold)
            + Text(" at \(timeLabel(event.startDate)).")
    }

    // MARK: - Agenda

    private var agenda: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("Today")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
                    .textCase(.uppercase)
                Text(dayLabel(now))
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textTertiary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 6)

            let events = meetingStore.calendarService.todaysEvents
            if events.isEmpty {
                Text("Nothing on your calendar.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 2) {
                        ForEach(events) { event in
                            EventRow(event: event, status: status(for: event), now: now) {
                                openWindow(id: "meeting")
                                NSApp.activate(ignoringOtherApps: true)
                                meetingStore.startRecording(from: event)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
                }
                .frame(maxHeight: 280)
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 10) {
            dateBadge(now)
            Button {
                SettingsWindowController.shared.show()
            } label: {
                HStack(spacing: 4) {
                    Text("Settings")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textPrimary)
                    Text("⌥⇧,")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.textTertiary)
                        .monospaced()
                }
            }
            .buttonStyle(.plain)
            .keyboardShortcut(",", modifiers: [.option, .shift])

            Spacer()

            Button {
                meetingStore.quit()
            } label: {
                HStack(spacing: 4) {
                    Text("Quit Convene")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textPrimary)
                    Text("⌘Q")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.textTertiary)
                        .monospaced()
                }
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.sidebarBackground)
        .overlay(alignment: .top) {
            DashedDivider()
        }
    }

    private func dateBadge(_ date: Date) -> some View {
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMM"
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "d"
        let month = monthFormatter.string(from: date).uppercased()
        let day = dayFormatter.string(from: date)
        return VStack(spacing: 0) {
            Text(month)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 1)
                .background(Color.accentOlive)
            Text(day)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity)
        }
        .frame(width: 28, height: 26)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(Color.cardBorder, lineWidth: 0.5)
        )
    }

    // MARK: - No access

    private var noAccessState: some View {
        VStack(spacing: 14) {
            IconBadge(systemName: "calendar", size: 44, iconSize: 20)
            Text("Convene needs Calendar access")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
            Text("Grant access to see today's events and start recording from a meeting.")
                .font(.system(size: 13))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button("Grant Calendar Access…") {
                Task { await meetingStore.calendarService.requestAccess() }
            }
            .buttonStyle(OliveProminentButtonStyle())
            DashedDivider()
            HStack {
                Button("Settings…") { SettingsWindowController.shared.show() }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.textPrimary)
                    .keyboardShortcut(",", modifiers: [.option, .shift])
                Spacer()
                Button("Quit Convene") { meetingStore.quit() }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.textPrimary)
                    .keyboardShortcut("q")
            }
            .font(.system(size: 13))
        }
        .padding(20)
    }

    // MARK: - Helpers

    private func openMeetingWindow() {
        openWindow(id: "meeting")
        NSApp.activate(ignoringOtherApps: true)
    }

    private func nextUpcomingEvent() -> MeetingEvent? {
        meetingStore.calendarService.todaysEvents
            .first(where: { $0.startDate > now })
    }

    private func status(for event: MeetingEvent) -> EventStatus {
        if event.endDate < now { return .past }
        if event.startDate <= now && now <= event.endDate { return .current }
        return .upcoming
    }

    private func greetingTitle(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        default: return "Good Evening"
        }
    }

    private func relativeStart(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let interval = date.timeIntervalSince(now)
        if interval <= 0 { return "now" }
        let raw = formatter.localizedString(fromTimeInterval: interval)
        if raw.hasPrefix("in ") {
            return String(raw.dropFirst(3))
        }
        return raw
    }

    private func timeLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.amSymbol = "am"
        formatter.pmSymbol = "pm"
        return formatter.string(from: date)
    }

    private func dayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }

    private func numberWord(_ value: Int) -> String {
        let words = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]
        if value < words.count { return words[value] }
        return String(value)
    }
}

private enum EventStatus {
    case past, current, upcoming
}

private struct EventRow: View {
    let event: MeetingEvent
    let status: EventStatus
    let now: Date
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                StatusCircle(status: status, color: tint)
                timeRange
                    .font(.system(size: 13).monospacedDigit())
                Text(event.title)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if event.attendees.count >= 1 {
                    HStack(spacing: 3) {
                        Image(systemName: "person")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.textTertiary)
                        Text("\(event.attendees.count)")
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundStyle(Color.textTertiary)
                    }
                }
                Image(systemName: "calendar")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(rowBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeInOut(duration: 0.12), value: hovering)
    }

    private var rowBackground: Color {
        if status == .current { return Color.accentOliveSoft }
        if hovering { return Color.hoverBackground }
        return .clear
    }

    private var timeRange: Text {
        Text(formatted(event.startDate)).foregroundColor(Color.textPrimary)
            + Text(" – \(formatted(event.endDate))").foregroundColor(Color.textTertiary)
    }

    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.amSymbol = "am"
        formatter.pmSymbol = "pm"
        return formatter.string(from: date)
    }

    private var tint: Color {
        if let nsColor = event.calendarColor {
            return Color(nsColor)
        }
        return Color.accentOlive
    }
}

private struct StatusCircle: View {
    let status: EventStatus
    let color: Color

    var body: some View {
        ZStack {
            switch status {
            case .past:
                Circle()
                    .fill(color.opacity(0.18))
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(color)
            case .current:
                Circle()
                    .stroke(color, lineWidth: 2)
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
            case .upcoming:
                Circle()
                    .stroke(color, lineWidth: 1.5)
            }
        }
        .frame(width: 16, height: 16)
    }
}

private struct OliveProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentOlive)
                    .opacity(configuration.isPressed ? 0.85 : 1)
            )
    }
}
