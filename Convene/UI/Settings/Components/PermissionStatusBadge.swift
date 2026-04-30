import SwiftUI

enum PermissionState {
    case granted
    case denied
    case notDetermined
    case restricted
    case provisional

    var label: String {
        switch self {
        case .granted:       return "Granted"
        case .denied:        return "Denied"
        case .notDetermined: return "Not requested"
        case .restricted:    return "Restricted"
        case .provisional:   return "Provisional"
        }
    }

    var fill: Color {
        switch self {
        case .granted:       return Color.accentOliveSoft
        case .denied:        return Color.iconBadgeBackground
        case .notDetermined: return Color.iconBadgeBackground
        case .restricted:    return Color.iconBadgeBackground
        case .provisional:   return Color.iconBadgeBackground
        }
    }

    var foreground: Color {
        switch self {
        case .granted:       return Color.accentOlive
        default:             return Color.textSecondary
        }
    }
}

struct PermissionStatusBadge: View {
    let state: PermissionState

    var body: some View {
        Text(state.label)
            .font(.pillLabel)
            .foregroundStyle(state.foreground)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(state.fill)
            )
    }
}
