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
    private var flagKeyMomentObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationActionHandler.shared.install()

        SettingsWindowController.shared.configure(
            meetingStore: meetingStore,
            hotkeyManager: hotkeyManager,
            updateManager: updateManager
        )
        MeetingLauncher.shared.configure(meetingStore: meetingStore)
        StatusItemController.shared.configure(meetingStore: meetingStore, hotkeyManager: hotkeyManager)
        StatusItemController.shared.installStatusItem()

        // `⌥⇧K` drops a key moment at the current offset (no-op when not recording). The flag is
        // silent — the menu bar stays the only UI surface.
        flagKeyMomentObserver = NotificationCenter.default.addObserver(
            forName: .conveneFlagKeyMoment, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.meetingStore.flagKeyMoment() }
        }

        meetingStore.recoverOrphanedMeetings()
        Task { await meetingStore.calendarService.refreshEvents() }

        runCaptureSmokeTestIfRequested()
    }

    private func runCaptureSmokeTestIfRequested() {
        #if DEBUG
        guard !didRunCaptureSmokeTest else { return }
        if let rawSeconds = ProcessInfo.processInfo.environment["CONVENE_TRANSCRIPTION_SMOKE_TEST_SECONDS"],
            let seconds = Double(rawSeconds),
            seconds > 0
        {
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
            seconds > 0
        else { return }
        didRunCaptureSmokeTest = true

        let baseURL = MeetingStore.debugWAVBaseURL()

        Task { @MainActor in
            logInfo("CaptureSmokeTest: starting for \(seconds)s at \(baseURL.path)")
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard await meetingStore.captureCoordinator.requestPermissions() else {
                logError(
                    "CaptureSmokeTest: start failed: \(meetingStore.captureCoordinator.startError ?? "permission required")"
                )
                NSApp.terminate(nil)
                return
            }
            meetingStore.captureCoordinator.debugWAVBaseURL = baseURL
            await meetingStore.captureCoordinator.start()
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
