import EventKit
import SwiftUI

struct CalendarPage: View {
    @ObservedObject private var settings = CalendarSettings.shared
    @EnvironmentObject var meetingStore: MeetingStore

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
            PageTitle("Calendar")

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionLabel("Enabled Calendars")
                SettingsCard {
                    enabledCalendarsContent
                }
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionLabel("Display")
                SettingsCard {
                    SettingsRow(
                        icon: "menubar.rectangle",
                        title: "Show in menu bar",
                        description: "Show the upcoming event this many minutes before it starts"
                    ) {
                        Picker("", selection: $settings.leadTimeMinutes) {
                            Text("5 minutes").tag(5)
                            Text("10 minutes").tag(10)
                            Text("15 minutes").tag(15)
                            Text("30 minutes").tag(30)
                        }
                        .pickerStyle(.menu)
                        .frame(minWidth: 130)
                        .labelsHidden()
                    }
                    SettingsRow(
                        icon: "video",
                        title: "Only show events with meetings",
                        description: "Hide events that don't have a join link",
                        showsDivider: false
                    ) {
                        Toggle("", isOn: $settings.onlyShowEventsWithMeetings)
                            .toggleStyle(OliveToggleStyle())
                            .labelsHidden()
                    }
                }
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionLabel("Behavior")
                SettingsCard {
                    SettingsRow(
                        icon: "safari",
                        title: "Browser for meeting links",
                        description: "Where Google Meet / Zoom links open"
                    ) {
                        Picker("", selection: $settings.browserBundleID) {
                            Text("System Default").tag("")
                            Text("Google Chrome").tag("com.google.Chrome")
                            Text("Safari").tag("com.apple.Safari")
                            Text("Arc").tag("company.thebrowser.Browser")
                            Text("Firefox").tag("org.mozilla.firefox")
                        }
                        .pickerStyle(.menu)
                        .frame(minWidth: 150)
                        .labelsHidden()
                    }
                    SettingsRow(
                        icon: "record.circle",
                        title: "Auto-record on join",
                        description: "Start recording automatically when you join a meeting",
                        showsDivider: false
                    ) {
                        Toggle("", isOn: $settings.autoRecordOnJoin)
                            .toggleStyle(OliveToggleStyle())
                            .labelsHidden()
                    }
                }
            }
        }
        .padding(.top, Theme.Spacing.xl)
    }

    // MARK: - Enabled Calendars

    @ViewBuilder
    private var enabledCalendarsContent: some View {
        let calendars = meetingStore.calendarService.allCalendars()
        if !meetingStore.calendarService.hasAccess || calendars.isEmpty {
            SettingsRow(
                icon: "calendar",
                title: "Calendar access needed",
                description: "Grant calendar access in Permissions to choose calendars",
                showsDivider: false
            ) {}
        } else {
            let groups = groupedCalendars(calendars)
            ForEach(Array(groups.enumerated()), id: \.element.account) { groupIndex, group in
                Text(group.account)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.Spacing.rowHorizontal)
                    .padding(.top, Theme.Spacing.md)
                    .padding(.bottom, Theme.Spacing.xs)

                ForEach(Array(group.calendars.enumerated()), id: \.element.calendarIdentifier) {
                    calIndex, cal in
                    let isLastRow = groupIndex == groups.count - 1 && calIndex == group.calendars.count - 1
                    calendarRow(cal, showsDivider: !isLastRow)
                }
            }
        }
    }

    private func calendarRow(_ cal: EKCalendar, showsDivider: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: Theme.Spacing.md) {
                Circle()
                    .fill(Color(nsColor: cal.color ?? .systemGray))
                    .frame(width: 10, height: 10)
                Text(cal.title)
                    .font(.rowTitle)
                    .foregroundStyle(Color.textPrimary)
                Spacer(minLength: Theme.Spacing.md)
                Toggle(
                    "",
                    isOn: Binding(
                        get: { settings.isCalendarEnabled(cal.calendarIdentifier) },
                        set: { settings.setCalendar(cal.calendarIdentifier, enabled: $0) }
                    )
                )
                .toggleStyle(OliveToggleStyle())
                .labelsHidden()
            }
            .padding(.horizontal, Theme.Spacing.rowHorizontal)
            .padding(.vertical, Theme.Spacing.rowVertical)

            if showsDivider {
                DashedDivider()
                    .padding(.horizontal, Theme.Spacing.rowHorizontal)
            }
        }
    }

    private struct CalendarGroup {
        let account: String
        let calendars: [EKCalendar]
    }

    private func groupedCalendars(_ calendars: [EKCalendar]) -> [CalendarGroup] {
        var order: [String] = []
        var buckets: [String: [EKCalendar]] = [:]
        for cal in calendars {
            let key = cal.source?.title ?? "Other"
            if buckets[key] == nil {
                buckets[key] = []
                order.append(key)
            }
            buckets[key]?.append(cal)
        }
        // Sort so "@"-containing accounts come first, preserving original discovery order within each tier.
        let sortedKeys = order.enumerated().sorted { lhs, rhs in
            let lhsEmail = lhs.element.contains("@")
            let rhsEmail = rhs.element.contains("@")
            if lhsEmail != rhsEmail { return lhsEmail }
            return lhs.offset < rhs.offset
        }.map(\.element)
        return sortedKeys.map { CalendarGroup(account: $0, calendars: buckets[$0] ?? []) }
    }
}
