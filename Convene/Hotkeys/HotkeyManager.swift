import Foundation
import Cocoa
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleRecording = Self("toggleRecording", default: .init(.r, modifiers: [.option, .shift]))
    static let openMeetingWindow = Self("openMeetingWindow", default: .init(.m, modifiers: [.option, .shift]))
    static let openSettings = Self("openSettings", default: .init(.comma, modifiers: [.option, .shift]))
}

@MainActor
class HotkeyManager: ObservableObject {
    @Published var recordingShortcutDisplay: String = ""
    @Published var meetingWindowShortcutDisplay: String = ""
    @Published var settingsShortcutDisplay: String = ""

    init() {
        logInfo("HotkeyManager: Initializing")
        refreshDisplays()

        KeyboardShortcuts.onKeyUp(for: .toggleRecording) {
            logDebug("HotkeyManager: toggleRecording")
            NotificationCenter.default.post(name: NSNotification.Name("ConveneToggleRecording"), object: nil)
        }

        KeyboardShortcuts.onKeyUp(for: .openMeetingWindow) {
            logDebug("HotkeyManager: openMeetingWindow")
            NotificationCenter.default.post(name: NSNotification.Name("ConveneOpenMeetingWindow"), object: nil)
        }

        KeyboardShortcuts.onKeyUp(for: .openSettings) {
            logDebug("HotkeyManager: openSettings")
            SettingsWindowController.shared.show()
        }
    }

    func refreshDisplays() {
        recordingShortcutDisplay = HotkeyManager.display(for: .toggleRecording)
        meetingWindowShortcutDisplay = HotkeyManager.display(for: .openMeetingWindow)
        settingsShortcutDisplay = HotkeyManager.display(for: .openSettings)
    }

    private static func display(for name: KeyboardShortcuts.Name) -> String {
        guard let shortcut = KeyboardShortcuts.getShortcut(for: name) else { return "Not set" }
        return shortcut.description
    }
}
