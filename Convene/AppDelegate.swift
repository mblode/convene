import AppKit
import SwiftUI

/// Owns the app's long-lived stores and wires up the AppKit-managed UI (status item, meeting and
/// settings windows). The menu bar popup and windows are all controller-hosted now, so no SwiftUI
/// scene needs these stores — the delegate is their single owner.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let meetingStore = MeetingStore()
    let hotkeyManager = HotkeyManager()
    let updateManager = UpdateManager()

    private var didRunCaptureSmokeTest = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationActionHandler.shared.install()

        SettingsWindowController.shared.configure(
            meetingStore: meetingStore,
            hotkeyManager: hotkeyManager,
            updateManager: updateManager
        )
        MeetingWindowController.shared.configure(meetingStore: meetingStore)
        MeetingLauncher.shared.configure(meetingStore: meetingStore)
        StatusItemController.shared.configure(meetingStore: meetingStore, hotkeyManager: hotkeyManager)
        StatusItemController.shared.installStatusItem()

        meetingStore.recoverOrphanedMeetings()
        Task { await meetingStore.calendarService.refreshEvents() }
        // Warm the transcription models in the background so the first recording starts instantly.
        Task(priority: .utility) { await meetingStore.transcriber.warmUp() }

        runCaptureSmokeTestIfRequested()
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
