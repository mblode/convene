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
    /// When on, quitting the last running meeting app auto-stops an in-progress recording.
    @Published var autoStopOnMeetingEnd: Bool = UserDefaults.standard.object(forKey: "autoStopOnMeetingEnd") as? Bool ?? true {
        didSet { UserDefaults.standard.set(autoStopOnMeetingEnd, forKey: "autoStopOnMeetingEnd") }
    }
    @Published private(set) var lastDetectedApp: String?
    @Published private(set) var notificationStatus: UNAuthorizationStatus = .notDetermined

    private var launchObserver: NSObjectProtocol?
    private var terminateObserver: NSObjectProtocol?
    private var seenBundleIDs = Set<String>()
    /// Tracked meeting apps currently running. Auto-stop fires only when this drains empty,
    /// so closing one of several open meeting apps doesn't cut a recording short.
    private var runningTrackedBundleIDs = Set<String>()

    init() {
        Task { await refreshNotificationStatus() }
        if enabled { startObserving() }
    }

    deinit {
        let center = NSWorkspace.shared.notificationCenter
        if let observer = launchObserver {
            center.removeObserver(observer)
        }
        if let observer = terminateObserver {
            center.removeObserver(observer)
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

    func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }

    private func startObserving() {
        guard launchObserver == nil else { return }
        let center = NSWorkspace.shared.notificationCenter
        let running = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier })
        // Seed with already-running apps so we don't re-notify on relaunch when the detector
        // toggles off and on.
        seenBundleIDs = running
        // Seed the running-tracked set so a quit during this session can be detected.
        runningTrackedBundleIDs = Set(Self.trackedApps.map(\.bundleID)).intersection(running)
        launchObserver = center.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            Task { @MainActor [weak self] in
                self?.handleLaunch(note)
            }
        }
        terminateObserver = center.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            Task { @MainActor [weak self] in
                self?.handleTerminate(note)
            }
        }
        logInfo("MeetingDetector: observing app launches and quits")
    }

    private func stopObserving() {
        let center = NSWorkspace.shared.notificationCenter
        if let observer = launchObserver {
            center.removeObserver(observer)
            launchObserver = nil
        }
        if let observer = terminateObserver {
            center.removeObserver(observer)
            terminateObserver = nil
        }
        runningTrackedBundleIDs = []
        logInfo("MeetingDetector: stopped observing")
    }

    private func handleLaunch(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleID = app.bundleIdentifier else { return }

        // Avoid double-fire on subsequent launches in the same session.
        if seenBundleIDs.contains(bundleID) { return }
        seenBundleIDs.insert(bundleID)

        guard let match = Self.trackedApps.first(where: { $0.bundleID == bundleID }) else { return }
        runningTrackedBundleIDs.insert(bundleID)
        lastDetectedApp = match.displayName
        Task { await postDetectionNotification(appName: match.displayName) }
    }

    private func handleTerminate(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleID = app.bundleIdentifier,
              Self.trackedApps.contains(where: { $0.bundleID == bundleID }) else { return }

        runningTrackedBundleIDs.remove(bundleID)
        guard autoStopOnMeetingEnd else { return }
        // Only treat the call as over once no tracked meeting app is left running.
        guard runningTrackedBundleIDs.isEmpty else { return }
        logInfo("MeetingDetector: last meeting app quit — signaling auto-stop")
        NotificationCenter.default.post(name: NSNotification.Name("ConveneMeetingAppsEnded"), object: nil)
    }

    private func postDetectionNotification(appName: String) async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationStatus = settings.authorizationStatus
        guard (settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional),
              settings.alertSetting != .disabled else {
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
