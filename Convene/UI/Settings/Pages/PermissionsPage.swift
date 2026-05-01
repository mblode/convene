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
                    systemAudioRow
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
        .task {
            await meetingStore.refreshPermissionStates()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await meetingStore.refreshPermissionStates() }
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
                switch state {
                case .notDetermined:
                    permissionButton("Enable", systemImage: "mic.fill") {
                        Task {
                            _ = await meetingStore.captureCoordinator.mic.requestPermission()
                            await meetingStore.refreshPermissionStates()
                        }
                    }
                case .denied, .restricted:
                    permissionButton("Open Settings", systemImage: "gearshape") {
                        openMicrophoneSettings()
                    }
                case .granted, .provisional, .requiresSettings:
                    EmptyView()
                }
            }
        }
    }

    // MARK: - System audio

    private var systemAudioRow: some View {
        let permission = meetingStore.captureCoordinator.system.permissionState
        let state = systemAudioState(permission)
        let waitingForMic = micState != .granted && !permission.isGranted

        return SettingsRow(
            icon: "speaker.wave.2.fill",
            title: "System Audio",
            description: systemAudioDescription(permission, waitingForMic: waitingForMic),
            isDisabled: waitingForMic
        ) {
            HStack(spacing: 8) {
                PermissionStatusBadge(state: waitingForMic ? .notDetermined : state)
                if !waitingForMic {
                    switch permission {
                    case .notDetermined:
                        permissionButton("Enable", systemImage: "speaker.wave.2.fill") {
                            enableSystemAudio()
                        }
                    case .requiresSystemSettings:
                        permissionButton("Open Settings", systemImage: "gearshape") {
                            meetingStore.captureCoordinator.system.openSystemSettings()
                        }
                    case .granted:
                        EmptyView()
                    }
                }
            }
        }
        .disabled(waitingForMic)
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
                switch state {
                case .notDetermined:
                    permissionButton("Enable", systemImage: "bell.fill") {
                        Task { await meetingStore.meetingDetector.requestNotificationAuthorization() }
                    }
                case .denied, .restricted:
                    permissionButton("Open Settings", systemImage: "gearshape") {
                        meetingStore.meetingDetector.openSystemSettings()
                    }
                case .granted, .provisional, .requiresSettings:
                    EmptyView()
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
                if meetingStore.calendarService.hasAccess {
                    permissionButton("Refresh", systemImage: "arrow.clockwise") {
                        Task { await meetingStore.calendarService.refreshEvents() }
                    }
                } else {
                    switch state {
                    case .notDetermined, .requiresSettings:
                        permissionButton("Enable", systemImage: "calendar") {
                            Task {
                                await meetingStore.calendarService.requestAccess()
                                await meetingStore.refreshPermissionStates()
                            }
                        }
                    case .denied, .restricted:
                        permissionButton("Open Settings", systemImage: "gearshape") {
                            meetingStore.calendarService.openSystemSettings()
                        }
                    case .granted, .provisional:
                        EmptyView()
                    }
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
        case .granted:       return "Ready to transcribe your voice"
        case .denied:        return "Denied — enable in System Settings"
        case .restricted:    return "Restricted by system policy"
        case .notDetermined: return "Required to transcribe your voice"
        case .provisional:   return "Provisional"
        case .requiresSettings: return "Needs setup in System Settings"
        }
    }

    private func systemAudioState(_ state: SystemAudioPermissionState) -> PermissionState {
        switch state {
        case .granted:                return .granted
        case .notDetermined:          return .notDetermined
        case .requiresSystemSettings: return .requiresSettings
        }
    }

    private func systemAudioDescription(_ state: SystemAudioPermissionState, waitingForMic: Bool) -> String {
        if waitingForMic {
            return "Enable Microphone first"
        }
        switch state {
        case .granted:
            return "Ready to transcribe other people's voices"
        case .notDetermined:
            return "Required to capture meeting audio from other apps"
        case .requiresSystemSettings:
            return "Enable Screen & System Audio Recording in System Settings"
        }
    }

    private var notificationState: PermissionState {
        switch meetingStore.meetingDetector.notificationStatus {
        case .authorized:    return .granted
        case .denied:        return .denied
        case .notDetermined: return .notDetermined
        case .provisional:   return .provisional
        @unknown default:    return .notDetermined
        }
    }

    private var notificationDescription: String {
        switch meetingStore.meetingDetector.notificationStatus {
        case .authorized:    return "Ready to show meeting-detected banners"
        case .denied:        return "Banners disabled — enable in System Settings"
        case .notDetermined: return "Required for the meeting-detected banner to appear"
        case .provisional:   return "Quiet delivery only"
        @unknown default:    return "Unknown"
        }
    }

    private var calendarState: PermissionState {
        if meetingStore.calendarService.hasAccess { return .granted }
        switch meetingStore.calendarService.authorizationStatus {
        case .denied:        return .denied
        case .restricted:    return .restricted
        case .notDetermined: return .notDetermined
        case .writeOnly:     return .requiresSettings
        case .authorized, .fullAccess: return .granted
        @unknown default:    return .notDetermined
        }
    }

    private var calendarDescription: String {
        if meetingStore.calendarService.hasAccess {
            let count = meetingStore.calendarService.todaysEvents.count
            return "\(count) event\(count == 1 ? "" : "s") today"
        }
        switch meetingStore.calendarService.authorizationStatus {
        case .denied:        return "Denied — enable in System Settings"
        case .restricted:    return "Restricted by system policy"
        case .notDetermined: return "Required to attach meetings to calendar events"
        case .writeOnly:     return "Write-only — full access required"
        default:             return "Unknown"
        }
    }

    // MARK: - Actions

    private func permissionButton(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.titleAndIcon)
        }
        .buttonStyle(.borderless)
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(Color.accentOlive)
    }

    private func enableSystemAudio() {
        Task {
            let granted = await meetingStore.captureCoordinator.system.requestPermission()
            await meetingStore.refreshPermissionStates()
            if !granted {
                meetingStore.captureCoordinator.system.openSystemSettings()
            }
        }
    }

    private func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
}
