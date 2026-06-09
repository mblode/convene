import SwiftUI
import AppKit

@main
struct ConveneApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The UI is AppKit-managed (status item + windows via controllers). An App needs at least
        // one Scene; Settings is invisible for an LSUIElement app and the real settings window is
        // shown via SettingsWindowController.
        Settings {
            EmptyView()
        }
    }
}
