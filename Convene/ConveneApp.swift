import SwiftUI
import AppKit

@main
struct ConveneApp: App {
    @StateObject private var meetingStore = MeetingStore()
    @StateObject private var hotkeyManager = HotkeyManager()

    init() {
        NotificationActionHandler.shared.install()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(meetingStore)
                .environmentObject(hotkeyManager)
                .onAppear { configureSettingsWindow() }
        } label: {
            MenuBarLabel()
                .environmentObject(meetingStore)
                .onAppear { configureSettingsWindow() }
        }
        .menuBarExtraStyle(.window)

        Window("Meeting", id: "meeting") {
            MeetingWindow()
                .environmentObject(meetingStore)
                .onAppear { configureSettingsWindow() }
        }
        .defaultSize(width: 720, height: 600)
    }

    private func configureSettingsWindow() {
        SettingsWindowController.shared.configure(
            meetingStore: meetingStore,
            hotkeyManager: hotkeyManager
        )
    }
}

private struct MenuBarLabel: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject var meetingStore: MeetingStore

    private var isCapturing: Bool { meetingStore.captureCoordinator.isCapturing }

    var body: some View {
        Image(systemName: "waveform")
            .symbolRenderingMode(isCapturing ? .palette : .monochrome)
            .foregroundStyle(isCapturing ? Color.recordingRed : Color.primary)
            .symbolEffect(.variableColor.iterative.reversing, isActive: isCapturing)
            .accessibilityLabel(isCapturing ? "Convene — recording" : "Convene")
            .help(isCapturing ? "Convene is recording" : "Convene")
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ConveneOpenMeetingWindow"))) { _ in
                openWindow(id: "meeting")
                NSApp.activate(ignoringOtherApps: true)
            }
    }
}
