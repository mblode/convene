import AppKit
import Foundation

/// Opens meeting links in the right place. For Google Meet it appends `?authuser=<owning account>`
/// so the link opens signed into the account that owns the event — the reliable approach when one
/// browser is signed into several Google accounts. Optionally starts Convene recording on join.
@MainActor
final class MeetingLauncher {
    static let shared = MeetingLauncher()

    private weak var meetingStore: MeetingStore?

    private init() {}

    func configure(meetingStore: MeetingStore) {
        self.meetingStore = meetingStore
    }

    /// Open the event's meeting link in the configured browser and (optionally) start recording.
    /// Pass `record` to override the "Auto-record on join" setting for this one join — e.g. `false`
    /// to join without starting a transcript regardless of the default.
    func join(_ event: MeetingEvent, record: Bool? = nil) {
        guard let url = launchURL(for: event) else {
            logError("MeetingLauncher: no meeting URL for \(event.title)")
            return
        }
        open(url)

        let shouldRecord = record ?? CalendarSettings.shared.autoRecordOnJoin
        if shouldRecord,
           let store = meetingStore,
           !store.captureCoordinator.isCapturing {
            store.startRecording(from: event)
        }
    }

    /// The final URL we open — Meet links get an `authuser` query for the owning account.
    func launchURL(for event: MeetingEvent) -> URL? {
        guard let base = event.meetingURL else { return nil }
        guard event.meetingService == .googleMeet,
              let email = event.accountEmail,
              var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            return base
        }
        var items = components.queryItems ?? []
        if !items.contains(where: { $0.name == "authuser" }) {
            items.append(URLQueryItem(name: "authuser", value: email))
        }
        components.queryItems = items
        return components.url ?? base
    }

    /// Open the system Calendar app (best effort — EventKit has no per-event deep link).
    func openCalendarApp() {
        if let calendarURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
            NSWorkspace.shared.open(calendarURL)
        }
    }

    /// Hide this event from the menu-bar pill.
    func dismiss(_ event: MeetingEvent) {
        CalendarSettings.shared.dismiss(eventID: event.id)
    }

    private func open(_ url: URL) {
        let config = NSWorkspace.OpenConfiguration()
        if let browser = CalendarSettings.shared.browserApplicationURL {
            NSWorkspace.shared.open([url], withApplicationAt: browser, configuration: config) { _, error in
                if let error {
                    logError("MeetingLauncher: browser open failed (\(error.localizedDescription)); using default")
                    DispatchQueue.main.async { NSWorkspace.shared.open(url) }
                }
            }
        } else {
            NSWorkspace.shared.open(url)
        }
    }
}
