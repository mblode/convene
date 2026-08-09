import Foundation
import EventKit
import AppKit

/// Conferencing provider detected from a meeting URL. Drives the "Join <service>" label.
enum MeetingService: String {
    case googleMeet
    case zoom
    case teams
    case webex
    case jitsi
    case whereby
    case other

    var joinLabel: String {
        switch self {
        case .googleMeet: return "Join Google Meet"
        case .zoom:       return "Join Zoom"
        case .teams:      return "Join Microsoft Teams"
        case .webex:      return "Join Webex"
        case .jitsi:      return "Join Jitsi"
        case .whereby:    return "Join Whereby"
        case .other:      return "Join Meeting"
        }
    }

    static func from(url: URL?) -> MeetingService? {
        guard let host = url?.host?.lowercased() else { return nil }
        if host.contains("meet.google.com") { return .googleMeet }
        if host.contains("zoom.us") { return .zoom }
        if host.contains("teams.microsoft.com") { return .teams }
        if host.contains("webex.com") { return .webex }
        if host.contains("meet.jit.si") { return .jitsi }
        if host.contains("whereby.com") { return .whereby }
        return .other
    }
}

/// Lightweight projection of an EKEvent for the UI / Meeting model.
struct MeetingEvent: Identifiable, Hashable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let attendees: [String]
    /// Display name (or email fallback) of the attendee EventKit marks as the current user, if any.
    let selfAttendeeName: String?
    /// Attendees excluding the current user, in calendar order.
    let otherAttendees: [String]
    let calendarTitle: String
    let calendarColor: NSColor?
    let calendarIdentifier: String
    /// Email of the account that owns the calendar this event lives on (for Google `authuser`).
    let accountEmail: String?
    let meetingURL: URL?
    let meetingService: MeetingService?

    var isInProgress: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }
}

/// Reads events from every calendar configured in macOS Calendar.app — iCloud, Google,
/// Fastmail/CalDAV, etc. EventKit aggregates all of them under a single store, so we don't
/// need per-provider auth.
@MainActor
final class CalendarService: ObservableObject {
    /// All non-all-day events in the lookahead window, across every enabled calendar, sorted by start.
    @Published private(set) var events: [MeetingEvent] = []
    @Published private(set) var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published private(set) var lastError: String?

    private let store = EKEventStore()
    private var changeObserver: NSObjectProtocol?
    /// Days of events to load ahead — enough for the Today/Tomorrow/this-week schedule.
    private let lookaheadDays = 7

    init() {
        refreshAuthorizationStatus()
        observeStoreChanges()
    }

    deinit {
        if let observer = changeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    var hasAccess: Bool {
        authorizationStatus == .fullAccess || authorizationStatus == .authorized
    }

    /// Events happening today only (kept for back-compat with existing call sites).
    var todaysEvents: [MeetingEvent] {
        let cal = Calendar.current
        return visibleEvents.filter { cal.isDateInToday($0.startDate) }
    }

    /// Events after applying the user's calendar/meeting filters.
    var visibleEvents: [MeetingEvent] {
        let settings = CalendarSettings.shared
        return events.filter { event in
            guard settings.isCalendarEnabled(event.calendarIdentifier) else { return false }
            if settings.onlyShowEventsWithMeetings && event.meetingURL == nil { return false }
            return true
        }
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    /// Triggers the macOS calendar permission prompt and refreshes events on success.
    func requestAccess() async {
        refreshAuthorizationStatus()
        switch authorizationStatus {
        case .fullAccess, .authorized:
            await refreshEvents()
            return
        case .denied:
            lastError = "Calendar access denied — open System Settings to enable"
            return
        case .restricted:
            lastError = "Calendar access restricted by system policy"
            return
        default:
            break
        }

        do {
            let granted = try await store.requestFullAccessToEvents()
            refreshAuthorizationStatus()
            if granted {
                await refreshEvents()
            } else {
                lastError = "Calendar access denied — open System Settings to enable"
            }
        } catch {
            lastError = "Calendar permission error: \(error.localizedDescription)"
            logError("CalendarService: \(error.localizedDescription)")
        }
    }

    func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }

    /// All event-type calendars, for the settings page's enable/disable list.
    func allCalendars() -> [EKCalendar] {
        guard hasAccess else { return [] }
        return store.calendars(for: .event)
    }

    /// Reload events across every calendar in the system store for the lookahead window.
    func refreshEvents() async {
        guard hasAccess else { return }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .day, value: lookaheadDays, to: start) else { return }

        // Passing `calendars: nil` matches every configured source — iCloud, Google, Fastmail, etc.
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let raw = store.events(matching: predicate)
        events = raw
            .filter { !$0.isAllDay }
            .map(MeetingEvent.init(event:))
            .sorted { $0.startDate < $1.startDate }
        lastError = nil
    }

    // MARK: - Schedule helpers

    /// The event to surface in the menu bar: the soonest non-dismissed, enabled event that is either
    /// in progress or starts within `leadMinutes`.
    func menuBarEvent(leadMinutes: Int) -> MeetingEvent? {
        let now = Date()
        let lead = TimeInterval(leadMinutes * 60)
        let dismissed = CalendarSettings.shared.dismissedEventIDs
        return visibleEvents.first { event in
            guard !dismissed.contains(event.id) else { return false }
            if event.isInProgress { return true }
            let untilStart = event.startDate.timeIntervalSince(now)
            return untilStart > 0 && untilStart <= lead
        }
    }

    /// The calendar event to attach to a recording the user starts manually (record button or
    /// hotkey) right now: an event already in progress, or one starting within the next 5 minutes.
    /// Returns nil when nothing matches, or when more than one event qualifies — ambiguity means
    /// we don't guess and fall back to the generic title. Dismissed events are ignored, matching
    /// the rest of the calendar surface.
    func currentEventForRecording() -> MeetingEvent? {
        let now = Date()
        let grace: TimeInterval = 5 * 60
        let dismissed = CalendarSettings.shared.dismissedEventIDs
        let matches = visibleEvents.filter { event in
            guard !dismissed.contains(event.id) else { return false }
            if event.isInProgress { return true }
            let untilStart = event.startDate.timeIntervalSince(now)
            return untilStart > 0 && untilStart <= grace
        }
        return matches.count == 1 ? matches.first : nil
    }

    /// Visible events grouped into ordered day buckets for the popover, e.g. "Today, 9 June".
    func groupedByDay() -> [DaySection] {
        let cal = Calendar.current
        let now = Date()
        // Show only today's events — including ones that already finished, which the popover
        // shows with a checkmark. Like Raycast's menu bar, the schedule stays scoped to today.
        // Drop events the user has dismissed from the menu.
        let startOfToday = cal.startOfDay(for: now)
        let dismissed = CalendarSettings.shared.dismissedEventIDs
        let upcoming = visibleEvents.filter {
            cal.isDateInToday($0.startDate) && $0.endDate >= startOfToday && !dismissed.contains($0.id)
        }
        let buckets = Dictionary(grouping: upcoming) { cal.startOfDay(for: $0.startDate) }
        return buckets.keys.sorted().map { day in
            DaySection(
                id: day,
                title: Self.dayLabel(for: day, now: now, calendar: cal),
                events: (buckets[day] ?? []).sorted { $0.startDate < $1.startDate }
            )
        }
    }

    struct DaySection: Identifiable {
        let id: Date
        let title: String
        let events: [MeetingEvent]
    }

    private static func dayLabel(for day: Date, now: Date, calendar: Calendar) -> String {
        let today = calendar.startOfDay(for: now)
        let dayStart = calendar.startOfDay(for: day)
        let dateText = day.formatted(.dateTime.weekday(.wide).day().month(.wide))
        if dayStart == today { return "Today, " + day.formatted(.dateTime.day().month(.wide)) }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today), dayStart == tomorrow {
            return "Tomorrow, " + day.formatted(.dateTime.day().month(.wide))
        }
        return dateText
    }

    private func observeStoreChanges() {
        changeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshEvents()
            }
        }
    }
}

private extension MeetingEvent {
    init(event: EKEvent) {
        self.id = event.eventIdentifier ?? UUID().uuidString
        self.title = event.title ?? "(Untitled)"
        self.startDate = event.startDate
        self.endDate = event.endDate
        let participants = event.attendees ?? []
        self.attendees = participants.map(MeetingEvent.displayValue(for:))
        self.selfAttendeeName = participants.first(where: { $0.isCurrentUser })
            .map(MeetingEvent.displayValue(for:))
        self.otherAttendees = participants
            .filter { !$0.isCurrentUser }
            .map(MeetingEvent.displayValue(for:))
        self.calendarTitle = event.calendar?.title ?? ""
        self.calendarColor = event.calendar?.color
        self.calendarIdentifier = event.calendar?.calendarIdentifier ?? ""
        self.accountEmail = MeetingEvent.accountEmail(for: event)
        let url = MeetingEvent.detectMeetingURL(in: event)
        self.meetingURL = url
        self.meetingService = MeetingService.from(url: url)
    }

    /// Participant's display name when set; otherwise the raw email from the `mailto:` URL.
    static func displayValue(for participant: EKParticipant) -> String {
        if let name = participant.name, !name.isEmpty { return name }
        // EKParticipant.url is usually mailto:; surface the raw email as a fallback.
        return participant.url.absoluteString.replacingOccurrences(of: "mailto:", with: "")
    }

    /// Email of the account that owns the event's calendar. Google CalDAV sources in macOS Calendar
    /// expose the account email either as the source title or inside `source.description` as a
    /// `mailto:` (the approach MeetingBar uses); fall back to the current-user attendee.
    static func accountEmail(for event: EKEvent) -> String? {
        if let sourceTitle = event.calendar?.source?.title, sourceTitle.contains("@") {
            return sourceTitle
        }
        if let description = event.calendar?.source?.description,
           let regex = try? NSRegularExpression(pattern: #"mailto:([^"\s>]+@[^"\s>]+)"#),
           let match = regex.firstMatch(in: description, range: NSRange(description.startIndex..., in: description)),
           let range = Range(match.range(at: 1), in: description) {
            return String(description[range])
        }
        if let me = (event.attendees ?? []).first(where: { $0.isCurrentUser }) {
            return me.url.absoluteString.replacingOccurrences(of: "mailto:", with: "")
        }
        return nil
    }

    static func detectMeetingURL(in event: EKEvent) -> URL? {
        // Search the obvious places for Zoom / Google Meet / Teams / Webex links.
        let haystacks: [String?] = [
            event.location,
            event.notes,
            event.url?.absoluteString,
            event.structuredLocation?.title
        ]
        let combined = haystacks.compactMap { $0 }.joined(separator: " ")
        guard let regex = try? NSRegularExpression(pattern: #"https?://[^\s)>"]+"#) else { return nil }
        let matches = regex.matches(in: combined, range: NSRange(combined.startIndex..., in: combined))
        for match in matches {
            guard let range = Range(match.range, in: combined) else { continue }
            let candidate = String(combined[range])
            if candidate.contains("zoom.us")
                || candidate.contains("meet.google.com")
                || candidate.contains("teams.microsoft.com")
                || candidate.contains("webex.com")
                || candidate.contains("meet.jit.si")
                || candidate.contains("whereby.com") {
                return URL(string: candidate)
            }
        }
        // Fall back to the EKEvent URL even if it isn't from a known provider.
        return event.url
    }
}
