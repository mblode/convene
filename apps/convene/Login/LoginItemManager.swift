import Combine
import Foundation
import ServiceManagement

/// Controls whether Convene launches automatically at login via SMAppService (macOS 13+).
/// The OS — not UserDefaults — is the source of truth; `refresh()` re-reads SMAppService.mainApp.status
/// so the toggle reflects changes the user makes in System Settings › General › Login Items.
@MainActor
final class LoginItemManager: ObservableObject {
    static let shared = LoginItemManager()

    /// True when Convene is registered to open at login (status == .enabled).
    @Published private(set) var isEnabled: Bool = false
    /// True when macOS requires the user to approve the item in System Settings (status == .requiresApproval).
    @Published private(set) var requiresApproval: Bool = false

    private init() {
        refresh()
    }

    func refresh() {
        let status = SMAppService.mainApp.status
        isEnabled = (status == .enabled)
        requiresApproval = (status == .requiresApproval)
    }

    /// Binding-friendly setter. Registers/unregisters and re-reads status; logs on failure.
    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog(
                "[LoginItem] Failed to \(enabled ? "register" : "unregister"): \(error.localizedDescription)")
        }
        refresh()
    }

    /// Opens System Settings to the Login Items pane (used when status is .requiresApproval).
    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
