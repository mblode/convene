import Foundation

enum SettingsSection: String, CaseIterable, Identifiable, Hashable {
    case general
    case models
    case capture
    case hotkeys
    case permissions
    case about

    var id: String { rawValue }

    var label: String {
        switch self {
        case .general:     return "General"
        case .models:      return "Models"
        case .capture:     return "Capture"
        case .hotkeys:     return "Hotkeys"
        case .permissions: return "Permissions"
        case .about:       return "About"
        }
    }

    var icon: String {
        switch self {
        case .general:     return "gearshape"
        case .models:      return "sparkles"
        case .capture:     return "waveform"
        case .hotkeys:     return "keyboard"
        case .permissions: return "lock.shield"
        case .about:       return "info.circle"
        }
    }
}
