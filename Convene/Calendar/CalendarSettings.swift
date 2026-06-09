import Foundation
import AppKit
import Combine

/// User preferences for the calendar / menu-bar-schedule feature. Singleton so the AppKit status
/// item, the SwiftUI popover, and the settings page all read and react to the same source of truth.
/// Persisted to UserDefaults via the `didSet` pattern used elsewhere in the app.
@MainActor
final class CalendarSettings: ObservableObject {
    static let shared = CalendarSettings()

    private enum Key {
        static let leadTimeMinutes = "calendar.leadTimeMinutes"
        static let browserBundleID = "calendar.browserBundleID"
        static let autoRecordOnJoin = "calendar.autoRecordOnJoin"
        static let disabledCalendarIDs = "calendar.disabledCalendarIDs"
        static let dismissedEventIDs = "calendar.dismissedEventIDs"
        static let onlyShowEventsWithMeetings = "calendar.onlyShowEventsWithMeetings"
    }

    /// How many minutes before an event the menu-bar pill appears.
    @Published var leadTimeMinutes: Int {
        didSet { UserDefaults.standard.set(leadTimeMinutes, forKey: Key.leadTimeMinutes) }
    }

    /// Bundle identifier of the browser used to open meeting/Google links. Empty = system default.
    @Published var browserBundleID: String {
        didSet { UserDefaults.standard.set(browserBundleID, forKey: Key.browserBundleID) }
    }

    /// Start Convene recording automatically when joining a meeting.
    @Published var autoRecordOnJoin: Bool {
        didSet { UserDefaults.standard.set(autoRecordOnJoin, forKey: Key.autoRecordOnJoin) }
    }

    /// EKCalendar identifiers the user has switched off — their events are hidden everywhere.
    @Published var disabledCalendarIDs: Set<String> {
        didSet { UserDefaults.standard.set(Array(disabledCalendarIDs), forKey: Key.disabledCalendarIDs) }
    }

    /// Event identifiers the user dismissed from the menu bar this session/run.
    @Published var dismissedEventIDs: Set<String> {
        didSet { UserDefaults.standard.set(Array(dismissedEventIDs), forKey: Key.dismissedEventIDs) }
    }

    /// Only surface events that have a detected meeting link.
    @Published var onlyShowEventsWithMeetings: Bool {
        didSet { UserDefaults.standard.set(onlyShowEventsWithMeetings, forKey: Key.onlyShowEventsWithMeetings) }
    }

    static let defaultBrowserBundleID = "com.google.Chrome"

    private init() {
        let defaults = UserDefaults.standard
        self.leadTimeMinutes = defaults.object(forKey: Key.leadTimeMinutes) as? Int ?? 10
        self.browserBundleID = defaults.string(forKey: Key.browserBundleID) ?? Self.defaultBrowserBundleID
        self.autoRecordOnJoin = defaults.object(forKey: Key.autoRecordOnJoin) as? Bool ?? true
        self.disabledCalendarIDs = Set(defaults.stringArray(forKey: Key.disabledCalendarIDs) ?? [])
        self.dismissedEventIDs = Set(defaults.stringArray(forKey: Key.dismissedEventIDs) ?? [])
        self.onlyShowEventsWithMeetings = defaults.object(forKey: Key.onlyShowEventsWithMeetings) as? Bool ?? false
    }

    func isCalendarEnabled(_ identifier: String) -> Bool {
        !disabledCalendarIDs.contains(identifier)
    }

    func setCalendar(_ identifier: String, enabled: Bool) {
        if enabled {
            disabledCalendarIDs.remove(identifier)
        } else {
            disabledCalendarIDs.insert(identifier)
        }
    }

    func dismiss(eventID: String) {
        dismissedEventIDs.insert(eventID)
    }

    func isDismissed(eventID: String) -> Bool {
        dismissedEventIDs.contains(eventID)
    }

    /// Resolve the browser app URL for the configured bundle id, falling back to nil (= system default).
    var browserApplicationURL: URL? {
        guard !browserBundleID.isEmpty else { return nil }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: browserBundleID)
    }
}
