import SwiftUI
import AppKit

@main
struct ConveneApp: App {
    @StateObject private var meetingStore = MeetingStore()
    @StateObject private var hotkeyManager = HotkeyManager()
    @State private var didRunCaptureSmokeTest = false

    init() {
        NotificationActionHandler.shared.install()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(meetingStore)
                .environmentObject(hotkeyManager)
                .onAppear {
                    configureSettingsWindow()
                    runCaptureSmokeTestIfRequested()
                }
        } label: {
            MenuBarLabel()
                .environmentObject(meetingStore)
                .onAppear {
                    configureSettingsWindow()
                    runCaptureSmokeTestIfRequested()
                }
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

    private func runCaptureSmokeTestIfRequested() {
        #if DEBUG
        guard !didRunCaptureSmokeTest else { return }
        if let rawSeconds = ProcessInfo.processInfo.environment["CONVENE_TRANSCRIPTION_SMOKE_TEST_SECONDS"],
           let seconds = Double(rawSeconds),
           seconds > 0 {
            didRunCaptureSmokeTest = true
            Task { @MainActor in
                logInfo("TranscriptionSmokeTest: starting for \(seconds)s")
                try? await Task.sleep(nanoseconds: 500_000_000)
                await meetingStore.runTranscriptionSmokeTest(seconds: seconds)
                NSApp.terminate(nil)
            }
            return
        }

        guard let rawSeconds = ProcessInfo.processInfo.environment["CONVENE_CAPTURE_SMOKE_TEST_SECONDS"],
              let seconds = Double(rawSeconds),
              seconds > 0 else { return }
        didRunCaptureSmokeTest = true

        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let baseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("convene-smoke-\(stamp)")

        Task { @MainActor in
            logInfo("CaptureSmokeTest: starting for \(seconds)s at \(baseURL.path)")
            try? await Task.sleep(nanoseconds: 500_000_000)
            await meetingStore.captureCoordinator.start(debugWAVBaseURL: baseURL)
            if let error = meetingStore.captureCoordinator.startError {
                logError("CaptureSmokeTest: start failed: \(error)")
                NSApp.terminate(nil)
                return
            }
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            await meetingStore.captureCoordinator.stop()
            logInfo("CaptureSmokeTest: finished at \(baseURL.path)")
            NSApp.terminate(nil)
        }
        #endif
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
