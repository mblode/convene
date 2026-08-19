import AppKit
import Combine
import Foundation

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
        static let dismissedEvents = "calendar.dismissedEvents"
        /// Pre-expiry format: a bare array of event identifiers, never pruned. Read once, then removed.
        static let legacyDismissedEventIDs = "calendar.dismissedEventIDs"
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

    /// Occurrences the user dismissed from the menu bar, keyed by `MeetingEvent.dismissalKey` and
    /// valued by the moment the dismissal stops mattering (the event's end). Pruned on every refresh
    /// so the set can't grow without bound.
    @Published private(set) var dismissedEvents: [String: Date] {
        didSet {
            let stored = dismissedEvents.mapValues { $0.timeIntervalSinceReferenceDate }
            UserDefaults.standard.set(stored, forKey: Key.dismissedEvents)
        }
    }

    /// Only surface events that have a detected meeting link.
    @Published var onlyShowEventsWithMeetings: Bool {
        didSet {
            UserDefaults.standard.set(onlyShowEventsWithMeetings, forKey: Key.onlyShowEventsWithMeetings)
        }
    }

    static let defaultBrowserBundleID = "com.google.Chrome"

    private init() {
        let defaults = UserDefaults.standard
        self.leadTimeMinutes = defaults.object(forKey: Key.leadTimeMinutes) as? Int ?? 10
        self.browserBundleID = defaults.string(forKey: Key.browserBundleID) ?? Self.defaultBrowserBundleID
        self.autoRecordOnJoin = defaults.object(forKey: Key.autoRecordOnJoin) as? Bool ?? true
        self.disabledCalendarIDs = Set(defaults.stringArray(forKey: Key.disabledCalendarIDs) ?? [])
        let storedDismissals = defaults.dictionary(forKey: Key.dismissedEvents) as? [String: Double] ?? [:]
        self.dismissedEvents = storedDismissals.mapValues(Date.init(timeIntervalSinceReferenceDate:))
        // The legacy list keyed whole recurring series and never expired, so one dismissal hid every
        // future occurrence forever. Nothing to migrate — drop it.
        defaults.removeObject(forKey: Key.legacyDismissedEventIDs)
        self.onlyShowEventsWithMeetings =
            defaults.object(forKey: Key.onlyShowEventsWithMeetings) as? Bool ?? false
        pruneExpiredDismissals()
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

    /// Hide a single occurrence until it has finished; later occurrences of a series are unaffected.
    func dismiss(_ event: MeetingEvent) {
        dismissedEvents[event.dismissalKey] = event.endDate
    }

    func isDismissed(_ event: MeetingEvent) -> Bool {
        guard let expiry = dismissedEvents[event.dismissalKey] else { return false }
        return expiry > Date()
    }

    /// Drop dismissals for events that have already ended.
    func pruneExpiredDismissals() {
        let now = Date()
        let live = dismissedEvents.filter { $0.value > now }
        if live.count != dismissedEvents.count { dismissedEvents = live }
    }

    /// Resolve the browser app URL for the configured bundle id, falling back to nil (= system default).
    var browserApplicationURL: URL? {
        guard !browserBundleID.isEmpty else { return nil }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: browserBundleID)
    }
}
