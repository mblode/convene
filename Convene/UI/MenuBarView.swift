import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var meetingStore: MeetingStore
    @Environment(\.openWindow) private var openWindow

    @State private var now: Date = Date()
    @State private var recordingStartedAt: Date?
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
        .onAppear {
            if meetingStore.captureCoordinator.isCapturing && recordingStartedAt == nil {
                recordingStartedAt = Date()
            }
        }
        .onChange(of: meetingStore.captureCoordinator.isCapturing) { _, capturing in
            recordingStartedAt = capturing ? Date() : nil
        }
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
            agenda
            footer
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Spacer()
            recordButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var recordButton: some View {
        let isCapturing = meetingStore.captureCoordinator.isCapturing
        return Button(action: { meetingStore.toggleRecording() }) {
            HStack(spacing: 6) {
                Image(systemName: isCapturing ? "stop.fill" : "record.circle.fill")
                    .font(.system(size: 11))
                Text(isCapturing ? recordingDurationText : "Record")
                    .font(.system(size: 13, weight: .medium))
                    .monospacedDigit()
                Text("⌥⇧R")
                    .font(.system(size: 10))
                    .monospaced()
                    .opacity(0.65)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .fill(isCapturing ? Color.recordingRed : Color.accentOlive)
            )
        }
        .buttonStyle(.plain)
        .keyboardShortcut("r", modifiers: [.option, .shift])
        .accessibilityLabel(isCapturing ? "Stop recording" : "Start recording")
    }

    private var recordingDurationText: String {
        guard let start = recordingStartedAt else { return "Stop" }
        let total = max(0, Int(now.timeIntervalSince(start)))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "Stop  %d:%02d:%02d", h, m, s)
            : String(format: "Stop  %d:%02d", m, s)
    }

    // MARK: - Agenda

    private var agenda: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("TODAY", date: now)

            let events = meetingStore.calendarService.todaysEvents
            if events.isEmpty {
                Text("Nothing on your calendar.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 1) {
                        ForEach(events) { event in
                            EventRow(event: event, status: status(for: event), now: now) {
                                openMeetingWindow()
                                guard !meetingStore.captureCoordinator.isCapturing else { return }
                                meetingStore.startRecording(from: event)
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.bottom, 6)
                }
                .frame(maxHeight: 320)
            }
        }
    }

    private func sectionHeader(_ title: String, date: Date) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .tracking(0.5)
            Text("·")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Text(date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 0) {
            Button {
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
            .help("Settings  ⌘,")
            .accessibilityLabel("Settings")

            Spacer()

            Menu {
                Button("Open Meeting Window") {
                    openMeetingWindow()
                }
                .keyboardShortcut("m", modifiers: [.option, .shift])

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
            Text("Convene needs access to show today's events and start recording from a meeting.")
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

    private func openMeetingWindow() {
        openWindow(id: "meeting")
        NSApp.activate(ignoringOtherApps: true)
    }

    private func status(for event: MeetingEvent) -> EventStatus {
        if event.endDate < now { return .past }
        if event.startDate <= now && now <= event.endDate { return .current }
        return .upcoming
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
            HStack(spacing: 10) {
                StatusCircle(status: status, color: tint)
                timeRange
                    .font(.system(size: 12).monospacedDigit())
                Text(event.title)
                    .font(.system(size: 13))
                    .foregroundStyle(status == .past ? Color.secondary : Color.primary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if event.attendees.count >= 1 {
                    HStack(spacing: 3) {
                        Image(systemName: "person")
                            .font(.system(size: 10))
                        Text("\(event.attendees.count)")
                            .font(.system(size: 11).monospacedDigit())
                    }
                    .foregroundStyle(.tertiary)
                }
            }
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
        .accessibilityHint("Opens the meeting window and starts recording if idle")
        .accessibilityAddTraits(.isButton)
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
        if status == .current { return Color.accentOliveSoft }
        if hovering { return Color.hoverBackground }
        return .clear
    }

    private var timeRange: Text {
        Text(formatted(event.startDate)).foregroundColor(Color.primary)
            + Text(" – \(formatted(event.endDate))").foregroundColor(Color.secondary)
    }

    private func formatted(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
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
                    .fill(Color.accentOlive)
                    .opacity(configuration.isPressed ? 0.85 : 1)
            )
    }
}
