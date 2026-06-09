import AppKit
import SwiftUI

/// Hosts the meeting window as an AppKit-managed `NSWindow` (mirrors `SettingsWindowController`).
/// We manage it directly rather than via a SwiftUI `Window` scene because the menu bar popup now
/// lives in a free-floating `NSPanel` (see `StatusItemController`), where `@Environment(\.openWindow)`
/// is not available. Keeping the window AppKit-owned means there's a single, reliable way to create
/// and surface it from anywhere (popup, hotkey, notifications).
@MainActor
final class MeetingWindowController {
    static let shared = MeetingWindowController()

    private weak var meetingStore: MeetingStore?
    private var windowController: NSWindowController?

    private init() {}

    func configure(meetingStore: MeetingStore) {
        self.meetingStore = meetingStore
    }

    /// Creates the meeting window on first call, then reuses and surfaces it.
    func show() {
        guard let meetingStore else {
            logError("MeetingWindowController: not configured")
            return
        }

        if windowController == nil {
            let host = NSHostingController(
                rootView: MeetingWindow()
                    .environmentObject(meetingStore)
            )
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 720, height: 600),
                styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "Meeting"
            window.titlebarAppearsTransparent = true
            window.contentViewController = host
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 720, height: 480)
            window.setFrameAutosaveName("ConveneMeetingWindow")
            window.center()
            windowController = NSWindowController(window: window)
        }

        NSApp.activate(ignoringOtherApps: true)
        windowController?.showWindow(nil)
        windowController?.window?.makeKeyAndOrderFront(nil)
    }
}
