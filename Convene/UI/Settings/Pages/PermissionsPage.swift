import AppKit
import SwiftUI

struct PermissionsPage: View {
    @EnvironmentObject var meetingStore: MeetingStore

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            PageTitle("Permissions")

            VStack(alignment: .leading, spacing: 12) {
                SectionLabel("System access")
                SettingsCard {
                    micRow
                    screenRow
                    notificationsRow
                    calendarRow
                }
                Text("Convene reads from every calendar configured in macOS Calendar.app — iCloud, Gmail, Fastmail, and any other CalDAV/Exchange accounts you've added in System Settings → Internet Accounts.")
                    .font(.captionWarm)
                    .foregroundStyle(Color.textSecondary)
                    .padding(.horizontal, 4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Mic

    private var micRow: some View {
        let state = micState
        return SettingsRow(
            icon: "mic.fill",
            title: "Microphone",
            description: micDescription(state)
        ) {
            HStack(spacing: 8) {
                PermissionStatusBadge(state: state)
                if state != .granted {
                    Button("Open Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.accentOlive)
                }
            }
        }
    }

    // MARK: - Screen

    private var screenRow: some View {
        let granted = meetingStore.captureCoordinator.system.hasScreenRecordingPermission
        let state: PermissionState = granted ? .granted : .denied
        return SettingsRow(
            icon: "rectangle.dashed.badge.record",
            title: "Screen Recording",
            description: granted ? "Granted" : "Required to capture system audio"
        ) {
            HStack(spacing: 8) {
                PermissionStatusBadge(state: state)
                if !granted {
                    Button("Open Settings") {
                        meetingStore.captureCoordinator.system.openSystemSettings()
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.accentOlive)
                }
            }
        }
    }

    // MARK: - Notifications

    private var notificationsRow: some View {
        let state = notificationState
        return SettingsRow(
            icon: "bell.fill",
            title: "Notifications",
            description: notificationDescription
        ) {
            HStack(spacing: 8) {
                PermissionStatusBadge(state: state)
                if state == .notDetermined {
                    Button("Request") {
                        Task { await meetingStore.meetingDetector.requestNotificationAuthorization() }
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.accentOlive)
                }
            }
        }
    }

    // MARK: - Calendar

    private var calendarRow: some View {
        let state = calendarState
        return SettingsRow(
            icon: "calendar",
            title: "Calendar",
            description: calendarDescription,
            showsDivider: false
        ) {
            HStack(spacing: 8) {
                PermissionStatusBadge(state: state)
                if !meetingStore.calendarService.hasAccess {
                    Button("Request") {
                        Task { await meetingStore.calendarService.requestAccess() }
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.accentOlive)
                } else {
                    Button("Refresh") {
                        Task { await meetingStore.calendarService.refreshEvents() }
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.accentOlive)
                }
            }
        }
    }

    // MARK: - State mappers

    private var micState: PermissionState {
        switch meetingStore.captureCoordinator.mic.permissionState {
        case .granted:       return .granted
        case .denied:        return .denied
        case .restricted:    return .restricted
        case .notDetermined: return .notDetermined
        }
    }

    private func micDescription(_ state: PermissionState) -> String {
        switch state {
        case .granted:       return "Granted"
        case .denied:        return "Denied — open System Settings to enable"
        case .restricted:    return "Restricted by system policy"
        case .notDetermined: return "Not yet requested"
        case .provisional:   return "Provisional"
        }
    }

    private var notificationState: PermissionState {
        switch meetingStore.meetingDetector.notificationStatus {
        case .authorized:    return .granted
        case .denied:        return .denied
        case .notDetermined: return .notDetermined
        case .provisional:   return .provisional
        case .ephemeral:     return .provisional
        @unknown default:    return .notDetermined
        }
    }

    private var notificationDescription: String {
        switch meetingStore.meetingDetector.notificationStatus {
        case .authorized:    return "Required for the meeting-detected banner to appear"
        case .denied:        return "Banners disabled — re-enable in System Settings"
        case .notDetermined: return "Not yet requested"
        case .provisional:   return "Quiet delivery only"
        case .ephemeral:     return "Ephemeral session"
        @unknown default:    return "Unknown"
        }
    }

    private var calendarState: PermissionState {
        if meetingStore.calendarService.hasAccess { return .granted }
        switch meetingStore.calendarService.authorizationStatus {
        case .denied:        return .denied
        case .restricted:    return .restricted
        case .notDetermined: return .notDetermined
        case .authorized, .fullAccess: return .granted
        case .writeOnly:     return .denied
        @unknown default:    return .notDetermined
        }
    }

    private var calendarDescription: String {
        if meetingStore.calendarService.hasAccess {
            let count = meetingStore.calendarService.todaysEvents.count
            return "\(count) event\(count == 1 ? "" : "s") today"
        }
        switch meetingStore.calendarService.authorizationStatus {
        case .denied:        return "Denied — open System Settings to enable"
        case .restricted:    return "Restricted by system policy"
        case .notDetermined: return "Not yet requested"
        case .writeOnly:     return "Write-only — full access required"
        default:             return "Unknown"
        }
    }
}
