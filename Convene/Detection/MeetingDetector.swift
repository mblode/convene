import Foundation
import AppKit
import UserNotifications

/// Detects when known meeting apps launch (Zoom, Teams, Webex, etc.) and posts a user
/// notification offering to start recording. Browser-based Meet/Zoom-Web detection is not
/// yet implemented (would require Accessibility-API window-title polling).
@MainActor
final class MeetingDetector: ObservableObject {
    /// Bundle IDs we treat as a meeting starting. Order matters only for the display label.
    static let trackedApps: [(bundleID: String, displayName: String)] = [
        ("us.zoom.xos", "Zoom"),
        ("com.microsoft.teams2", "Microsoft Teams"),
        ("com.microsoft.teams", "Microsoft Teams"),
        ("com.cisco.webexmeetingsapp", "Webex"),
        ("com.cisco.webex.meetings", "Webex"),
        ("com.google.GoogleMeet", "Google Meet"),
        ("com.bluejeansnet.BlueJeans", "BlueJeans"),
        ("com.tinyspeck.slackmacgap", "Slack")
    ]

    @Published var enabled: Bool = UserDefaults.standard.object(forKey: "meetingAutoDetect") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(enabled, forKey: "meetingAutoDetect")
            if enabled { startObserving() } else { stopObserving() }
        }
    }
    @Published private(set) var lastDetectedApp: String?
    @Published private(set) var notificationStatus: UNAuthorizationStatus = .notDetermined

    private var launchObserver: NSObjectProtocol?
    private var seenBundleIDs = Set<String>()

    init() {
        Task { await refreshNotificationStatus() }
        if enabled { startObserving() }
    }

    deinit {
        if let observer = launchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationStatus = settings.authorizationStatus
    }

    func requestNotificationAuthorization() async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        } catch {
            logError("MeetingDetector: notification auth error: \(error.localizedDescription)")
        }
        await refreshNotificationStatus()
    }

    private func startObserving() {
        guard launchObserver == nil else { return }
        // Seed with already-running apps so we don't re-notify on relaunch when the detector
        // toggles off and on.
        seenBundleIDs = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier })
        launchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            Task { @MainActor [weak self] in
                self?.handleLaunch(note)
            }
        }
        logInfo("MeetingDetector: observing app launches")
    }

    private func stopObserving() {
        if let observer = launchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            launchObserver = nil
        }
        logInfo("MeetingDetector: stopped observing")
    }

    private func handleLaunch(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleID = app.bundleIdentifier else { return }

        // Avoid double-fire on subsequent launches in the same session.
        if seenBundleIDs.contains(bundleID) { return }
        seenBundleIDs.insert(bundleID)

        guard let match = Self.trackedApps.first(where: { $0.bundleID == bundleID }) else { return }
        lastDetectedApp = match.displayName
        Task { await postDetectionNotification(appName: match.displayName) }
    }

    private func postDetectionNotification(appName: String) async {
        guard notificationStatus == .authorized || notificationStatus == .provisional else {
            logInfo("MeetingDetector: \(appName) launched but notification permission missing")
            return
        }
        let content = UNMutableNotificationContent()
        content.title = "\(appName) launched"
        content.body = "Tap to start recording this meeting."
        content.categoryIdentifier = "ConveneMeetingDetected"
        content.sound = .default

        let category = UNNotificationCategory(
            identifier: "ConveneMeetingDetected",
            actions: [
                UNNotificationAction(identifier: "ConveneStart", title: "Start Recording", options: [.foreground])
            ],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])

        let request = UNNotificationRequest(
            identifier: "convene-detect-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            logError("MeetingDetector: add notification failed: \(error.localizedDescription)")
        }
    }
}
