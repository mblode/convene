import Foundation
import EventKit
import AppKit

/// Lightweight projection of an EKEvent for the UI / Meeting model.
struct MeetingEvent: Identifiable, Hashable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let attendees: [String]
    let calendarTitle: String
    let calendarColor: NSColor?
    let meetingURL: URL?

    var isInProgress: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }

    var startsWithinNextHour: Bool {
        let interval = startDate.timeIntervalSinceNow
        return interval > 0 && interval <= 3600
    }
}

/// Reads events from every calendar configured in macOS Calendar.app — iCloud, Google,
/// Fastmail/CalDAV, etc. EventKit aggregates all of them under a single store, so we don't
/// need per-provider auth.
@MainActor
final class CalendarService: ObservableObject {
    @Published private(set) var todaysEvents: [MeetingEvent] = []
    @Published private(set) var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published private(set) var lastError: String?

    private let store = EKEventStore()
    private var changeObserver: NSObjectProtocol?

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
        authorizationStatus == .fullAccess
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    /// Triggers the macOS calendar permission prompt and refreshes events on success.
    func requestAccess() async {
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

    /// Reload today's events across every calendar in the system store.
    func refreshEvents() async {
        guard hasAccess else { return }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return }

        // Passing `calendars: nil` matches every configured source — iCloud, Google, Fastmail, etc.
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = store.events(matching: predicate)
        todaysEvents = events
            .filter { !$0.isAllDay }
            .map(MeetingEvent.init(event:))
            .sorted { $0.startDate < $1.startDate }
        lastError = nil
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
        self.attendees = (event.attendees ?? []).compactMap { participant -> String? in
            if let name = participant.name, !name.isEmpty { return name }
            // EKParticipant.url is usually mailto:; surface the raw email as a fallback.
            return participant.url.absoluteString.replacingOccurrences(of: "mailto:", with: "")
        }
        self.calendarTitle = event.calendar?.title ?? ""
        self.calendarColor = event.calendar?.color
        self.meetingURL = MeetingEvent.detectMeetingURL(in: event)
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
