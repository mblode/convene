import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var meetingStore: MeetingStore
    @ObservedObject private var calendarSettings = CalendarSettings.shared

    @State private var now: Date = Date()
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .frame(width: 360)
        .task {
            await meetingStore.calendarService.refreshEvents()
        }
        .onReceive(tick) { now = $0 }
    }

    @ViewBuilder
    private var content: some View {
        if !meetingStore.calendarService.hasAccess {
            noAccessState
        } else {
            header
            if let active = activeEvent {
                contextualActions(for: active)
                Divider().opacity(0.5).padding(.horizontal, 12)
            }
            schedule
            footer
        }
    }

    /// The imminent/in-progress event surfaced in the menu bar pill — the one the top actions target.
    private var activeEvent: MeetingEvent? {
        meetingStore.calendarService.menuBarEvent(leadMinutes: calendarSettings.leadTimeMinutes)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 4) {
            HStack(spacing: Theme.Spacing.sm) {
                statusLabel
                Spacer(minLength: Theme.Spacing.sm)
                recordButton
            }
            if let banner = meetingStore.headerBanner {
                Text(banner.text)
                    .font(.system(size: 11))
                    .foregroundStyle(banner.isError ? Color.recordingRed : Color.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 10)
        .animation(.easeInOut(duration: 0.2), value: meetingStore.captureCoordinator.isCapturing)
        .animation(.easeInOut(duration: 0.2), value: meetingStore.headerBanner?.text)
    }

    /// Left side of the header. Carries recording *status* (so the button can carry the *action*):
    /// a live pulse and elapsed time while capturing, otherwise the quiet wordmark.
    @ViewBuilder
    private var statusLabel: some View {
        if meetingStore.captureCoordinator.isCapturing {
            HStack(spacing: 6) {
                PulsingDot(color: .recordingRed)
                Text(recordingElapsedText)
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .transition(.opacity)
        } else {
            Text("Convene")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .transition(.opacity)
        }
    }

    private var recordButton: some View {
        let isCapturing = meetingStore.captureCoordinator.isCapturing
        // Starting a recording takes a moment (permissions, model load, capture start). Show a
        // spinner while that's in flight so the click has immediate affordance.
        let isBusy = meetingStore.isToggling
        return Button(action: { meetingStore.toggleRecording() }) {
            HStack(spacing: 6) {
                if isBusy {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                    Text(meetingStore.togglePhase == .stopping ? "Stopping…" : "Starting…")
                        .font(.system(size: 13, weight: .medium))
                } else {
                    Image(systemName: isCapturing ? "stop.fill" : "record.circle.fill")
                        .font(.system(size: 11))
                    Text(isCapturing ? "Stop" : "Record")
                        .font(.system(size: 13, weight: .medium))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .fill(isCapturing ? Color.recordingRed : Color.accent)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isBusy)
        .keyboardShortcut("r", modifiers: [.option, .shift])
        .accessibilityLabel(isCapturing ? "Stop recording" : "Start recording")
    }

    private var recordingElapsedText: String {
        guard let start = meetingStore.meetingStartedAt else { return "0:00" }
        let total = max(0, Int(now.timeIntervalSince(start)))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    // MARK: - Contextual actions (active event)

    @ViewBuilder
    private func contextualActions(for event: MeetingEvent) -> some View {
        VStack(spacing: 1) {
            if event.meetingURL != nil {
                if !meetingStore.captureCoordinator.isCapturing {
                    ActionRow(icon: "record.circle", label: "Join and Record", tint: Color.accent) {
                        MeetingLauncher.shared.join(event, record: true)
                        StatusItemController.shared.hidePanel()
                    }
                }
                ActionRow(icon: "video.fill", label: event.meetingService?.joinLabel ?? "Join Meeting") {
                    MeetingLauncher.shared.join(event, record: false)
                    StatusItemController.shared.hidePanel()
                }
            }
            ActionRow(icon: "calendar", label: "Open in Calendar") {
                MeetingLauncher.shared.openInCalendar(event)
                StatusItemController.shared.hidePanel()
            }
            ActionRow(icon: "xmark.circle", label: "Dismiss Event", tint: Color.secondary) {
                MeetingLauncher.shared.dismiss(event)
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 4)
    }

    // MARK: - Schedule

    private var schedule: some View {
        let sections = meetingStore.calendarService.groupedByDay()
        return VStack(alignment: .leading, spacing: 0) {
            if sections.isEmpty {
                dayHeader("Today, " + now.formatted(.dateTime.day().month(.wide)))
                VStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 22))
                        .foregroundStyle(.tertiary)
                    Text("Nothing scheduled")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(sections) { section in
                            dayHeader(section.title)
                            VStack(spacing: 1) {
                                ForEach(section.events) { event in
                                    EventRow(
                                        event: event,
                                        status: status(for: event),
                                        now: now,
                                        canJoin: event.meetingURL != nil
                                    ) {
                                        rowTapped(event)
                                    }
                                    .contextMenu { eventContextMenu(for: event) }
                                }
                            }
                            .padding(.horizontal, 6)
                            .padding(.bottom, 6)
                        }
                    }
                }
                .frame(maxHeight: 360)
            }
        }
    }

    private func dayHeader(_ title: String) -> some View {
        Text(title)
            .font(.pillLabel.weight(.medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 4)
    }

    private func rowTapped(_ event: MeetingEvent) {
        // Clicking an event records it — joining first when it has a meeting link. This is the
        // primary record affordance; no detection or notification is involved.
        let alreadyRecording = meetingStore.captureCoordinator.isCapturing
        if event.meetingURL != nil {
            MeetingLauncher.shared.join(event, record: !alreadyRecording)
        } else if status(for: event) != .past, !alreadyRecording {
            meetingStore.startRecording(from: event)
        } else {
            // Already recording, or a finished event with no link — leave the panel open
            // rather than closing on a tap that did nothing.
            return
        }
        StatusItemController.shared.hidePanel()
    }

    @ViewBuilder
    private func eventContextMenu(for event: MeetingEvent) -> some View {
        if event.meetingURL != nil {
            Button {
                MeetingLauncher.shared.join(event, record: true)
                StatusItemController.shared.hidePanel()
            } label: {
                Label("Join and Record", systemImage: "record.circle")
            }
            Button {
                MeetingLauncher.shared.join(event, record: false)
                StatusItemController.shared.hidePanel()
            } label: {
                Label("Join Without Recording", systemImage: "video")
            }
            Divider()
        }
        Button {
            MeetingLauncher.shared.openInCalendar(event)
            StatusItemController.shared.hidePanel()
        } label: {
            Label("Open in Calendar", systemImage: "calendar")
        }
        Button {
            MeetingLauncher.shared.dismiss(event)
        } label: {
            Label("Dismiss Event", systemImage: "xmark.circle")
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 0) {
            Button {
                StatusItemController.shared.hidePanel()
                SettingsWindowController.shared.show()
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Image(systemName: "gear")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(",", modifiers: .command)
            .help("Settings")
            .accessibilityLabel("Settings")

            Spacer()

            Menu {
                Button("Open Latest Transcript") {
                    if let url = meetingStore.persistence.latestTranscriptURL() {
                        meetingStore.persistence.openFile(url)
                    }
                }
                .disabled(meetingStore.persistence.outputFolderURL == nil
                    && meetingStore.persistence.lastSavedFileURL == nil)

                Divider()

                Button("Quit Convene") {
                    meetingStore.quit()
                }
                .keyboardShortcut("q")
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 28)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 32, height: 28)
            .help("More")
            .accessibilityLabel("More options")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .overlay(alignment: .top) {
            Divider().opacity(0.5)
        }
    }

    // MARK: - No access

    private var noAccessState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("Calendar access required")
                .font(.system(size: 14, weight: .medium))
            Text("Convene needs access to show your schedule and join meetings.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button("Grant Calendar Access…") {
                Task { await meetingStore.calendarService.requestAccess() }
            }
            .buttonStyle(OliveProminentButtonStyle())
            .padding(.top, 4)

            HStack {
                Button("Settings") {
                    StatusItemController.shared.hidePanel()
                    SettingsWindowController.shared.show()
                    NSApp.activate(ignoringOtherApps: true)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .keyboardShortcut(",", modifiers: .command)
                Spacer()
                Button("Quit") { meetingStore.quit() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .keyboardShortcut("q")
            }
            .font(.system(size: 12))
            .padding(.top, 4)
        }
        .padding(20)
    }

    // MARK: - Helpers

    private func status(for event: MeetingEvent) -> EventStatus {
        if event.endDate < now { return .past }
        if event.startDate <= now && now <= event.endDate { return .current }
        return .upcoming
    }
}

private enum EventStatus {
    case past, current, upcoming
}

private struct ActionRow: View {
    let icon: String
    let label: String
    var tint: Color = .primary
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .frame(width: 18)
                Text(label)
                    .font(.system(size: 13))
                Spacer()
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(hovering ? Color.hoverBackground : .clear,
                       in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeInOut(duration: 0.12), value: hovering)
        .accessibilityLabel(label)
    }
}

private struct EventRow: View {
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
            .background(rowBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
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
                .foregroundStyle(status == .current ? Color.white : Color.accent)
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
            .foregroundStyle(.tertiary)
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

/// A small dot that gently breathes — used as the live recording indicator in the header.
private struct PulsingDot: View {
    let color: Color
    @State private var pulsing = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .opacity(pulsing ? 0.35 : 1)
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulsing)
            .onAppear { pulsing = true }
            .accessibilityHidden(true)
    }
}

private struct StatusCircle: View {
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

private struct OliveProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .fill(Color.accent)
                    .opacity(configuration.isPressed ? 0.85 : 1)
            )
    }
}
