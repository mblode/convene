import SwiftUI
import AppKit

@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private weak var meetingStore: MeetingStore?
    private weak var hotkeyManager: HotkeyManager?
    private var windowController: NSWindowController?

    private init() {}

    func configure(meetingStore: MeetingStore, hotkeyManager: HotkeyManager) {
        self.meetingStore = meetingStore
        self.hotkeyManager = hotkeyManager
    }

    func show() {
        guard let meetingStore, let hotkeyManager else {
            logError("SettingsWindowController: not configured")
            return
        }

        if windowController == nil {
            let host = NSHostingController(
                rootView: SettingsView()
                    .environmentObject(meetingStore)
                    .environmentObject(hotkeyManager)
            )
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 860, height: 680),
                styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "Convene Settings"
            window.titlebarAppearsTransparent = true
            window.contentViewController = host
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 760, height: 600)
            window.setFrameAutosaveName("ConveneSettingsWindow")
            window.center()
            windowController = NSWindowController(window: window)
        }

        NSApp.activate(ignoringOtherApps: true)
        windowController?.showWindow(nil)
        windowController?.window?.makeKeyAndOrderFront(nil)
    }
}
