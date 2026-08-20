import Cocoa
import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleRecording = Self("toggleRecording", default: .init(.r, modifiers: [.option, .shift]))
    static let openSettings = Self("openSettings", default: .init(.comma, modifiers: [.option, .shift]))
    static let flagKeyMoment = Self("flagKeyMoment", default: .init(.k, modifiers: [.option, .shift]))
}

extension Notification.Name {
    static let conveneFlagKeyMoment = Notification.Name("ConveneFlagKeyMoment")
}

@MainActor
class HotkeyManager: ObservableObject {
    @Published var recordingShortcutDisplay: String = ""
    @Published var settingsShortcutDisplay: String = ""
    @Published var keyMomentShortcutDisplay: String = ""

    init() {
        logInfo("HotkeyManager: Initializing")
        refreshDisplays()

        KeyboardShortcuts.onKeyUp(for: .toggleRecording) {
            logDebug("HotkeyManager: toggleRecording")
            NotificationCenter.default.post(name: NSNotification.Name("ConveneToggleRecording"), object: nil)
        }

        KeyboardShortcuts.onKeyUp(for: .openSettings) {
            logDebug("HotkeyManager: openSettings")
            SettingsWindowController.shared.show()
        }

        KeyboardShortcuts.onKeyUp(for: .flagKeyMoment) {
            logDebug("HotkeyManager: flagKeyMoment")
            NotificationCenter.default.post(name: .conveneFlagKeyMoment, object: nil)
        }
    }

    func refreshDisplays() {
        recordingShortcutDisplay = HotkeyManager.display(for: .toggleRecording)
        settingsShortcutDisplay = HotkeyManager.display(for: .openSettings)
        keyMomentShortcutDisplay = HotkeyManager.display(for: .flagKeyMoment)
    }

    private static func display(for name: KeyboardShortcuts.Name) -> String {
        guard let shortcut = KeyboardShortcuts.getShortcut(for: name) else { return "Not set" }
        return shortcut.description
    }
}
