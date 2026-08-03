import SwiftUI

/// Every meeting Convene has saved on this phone, grouped by the day it happened, newest first.
///
/// A `ScrollView` of cards rather than a `List`: the rows here are a title, a row of chips and a
/// paragraph of summary, and `List` would spend a separator and a chevron on each one saying things
/// the card already says. What `List` also supplies — swipe to delete, row separators, its own
/// background — is either rebuilt below or deliberately gone.
struct MeetingsView: View {
    @EnvironmentObject private var store: MobileMeetingStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Rows awaiting confirmation. Deleting removes the transcript *and* the markdown file from
    /// the user's folder, with nothing to undo it, so a swipe alone shouldn't be enough.
    @State private var pendingDeletion: [Meeting] = []
    @State private var searchText = ""
    @State private var isShowingSettings = false

    /// Below this many meetings the whole library is a flick away and a search field is one more
    /// thing standing between the user and it.
    private static let searchThreshold = 10

    /// Keeps the last card clear of the record button floating over this screen.
    ///
    /// Scaled, because the button it is making room for is scaled too: `RecordFAB` sizes itself
    /// with `@ScaledMetric`, so at an accessibility text size a fixed inset leaves the last card
    /// sliding under a control half again as tall as it was.
    @ScaledMetric(relativeTo: .body) private var floatingControlInset: CGFloat = 96

    var body: some View {
        searchableContent
            // The system's own large title, not `.typeStyle(.title)`: it is the same face, weight
            // and size, and it is what `.searchable` docks its field beneath and what collapses
            // into the bar on scroll. A hand-drawn title in the content would have to give up both.
            .navigationTitle("Meetings")
            .background(Color.appBackground.ignoresSafeArea())
            .toolbar { settingsButton }
            .sheet(isPresented: $isShowingSettings) { SettingsView() }
            .confirmationDialog(
                pendingDeletion.count == 1
                    ? "Delete this meeting?" : "Delete \(pendingDeletion.count) meetings?",
                isPresented: Binding(
                    get: { !pendingDeletion.isEmpty },
                    set: { if !$0 { pendingDeletion = [] } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    pendingDeletion.forEach(store.deleteMeeting)
                    pendingDeletion = []
                }
                Button("Cancel", role: .cancel) { pendingDeletion = [] }
            } message: {
                Text(deletionMessage)
            }
            // Routing by id rather than by value: the summary lands a few seconds after the meeting is
            // saved, and looking it up on each render means an already-open detail view picks it up
            // instead of showing the copy that was pushed.
            .navigationDestination(for: UUID.self) { id in
                if let meeting = store.library.meetings.first(where: { $0.id == id }) {
                    MeetingDetailView(meeting: meeting)
                } else {
                    ContentUnavailableView("Meeting not found", systemImage: "questionmark.folder")
                }
            }
            .onAppear { store.library.reload() }
    }

    /// Crossing the search threshold rebuilds the scroll view and drops the user's place in it.
    /// That happens once, on the eleventh meeting they ever save, which is a cheaper moment to
    /// spend than every launch before it with a search field over a list of four.
    @ViewBuilder private var searchableContent: some View {
        if isSearchable {
            content.searchable(text: $searchText, prompt: "Search meetings")
        } else {
            content
        }
    }

    @ViewBuilder private var content: some View {
        VStack(spacing: 0) {
            // Above whatever the list is doing, because a meeting that failed to save outlives the
            // screen it failed on: the recording sheet is gone by then, and the library it would
            // have joined is the one place the user is certain to come back to.
            if let error = store.pendingSaveError {
                SaveFailureBanner(message: error, retry: store.retryPendingSave)
                    .padding(.horizontal, MobileTheme.Spacing.lg)
                    .padding(.bottom, MobileTheme.Spacing.md)
            }

            // The read-failure case has to be caught before the empty one. `reload()` returns early
            // when it can't list the directory, leaving `meetings` untouched — so a first-launch
            // failure arrives here as an empty library, and telling someone their meetings are gone
            // when the app simply couldn't open the folder is the worst sentence a recorder can
            // say.
            if let error = store.library.lastError, store.library.meetings.isEmpty {
                libraryFailure(error)
            } else if store.library.meetings.isEmpty {
                emptyState
            } else if sections.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                meetingList
            }
        }
        .animation(reduceMotion ? nil : MobileTheme.Motion.quiet, value: store.pendingSaveError)
    }

    private var meetingList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: MobileTheme.Spacing.xl) {
                if let error = store.library.lastError {
                    BannerView(text: error, isError: true)
                }

                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: MobileTheme.Spacing.md) {
                        Text(section.title)
                            .typeStyle(.section)
                            .foregroundStyle(Color.textSecondary)
                            .accessibilityAddTraits(.isHeader)

                        ForEach(section.meetings) { meeting in
                            card(for: meeting)
                        }
                    }
                }
            }
            .padding(.horizontal, MobileTheme.Spacing.lg)
            .padding(.top, MobileTheme.Spacing.sm)
            .padding(.bottom, floatingControlInset)
            // A meeting arriving or leaving moves everything under it. Animating the library rather
            // than the search results is deliberate: a card that vanishes as you type is the field
            // doing its job, and does not need to be narrated.
            .animation(reduceMotion ? nil : MobileTheme.Motion.standard, value: store.library.meetings)
        }
        .scrollDismissesKeyboard(.immediately)
    }

    private func card(for meeting: Meeting) -> some View {
        NavigationLink(value: meeting.id) {
            MeetingCard(meeting: meeting)
        }
        .buttonStyle(PressableStyle(RoundedRectangle(cornerRadius: MobileTheme.Radius.card)))
        // Without `List` there is nothing to swipe, so the destructive action lives in the long
        // press. Matching the preview shape to the card keeps the lift from tearing off a
        // rectangle with the card's own corners inside it.
        .contentShape(
            .contextMenuPreview, RoundedRectangle(cornerRadius: MobileTheme.Radius.card)
        )
        .contextMenu {
            Button(role: .destructive) {
                pendingDeletion = [meeting]
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    @ToolbarContentBuilder private var settingsButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            // A sheet rather than a push: settings is a detour from the list, not somewhere further
            // into it, and `SettingsView` brings its own navigation stack for the pickers inside it.
            Button {
                isShowingSettings = true
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
        }
    }

    // MARK: - Empty state

    /// An empty library means one of two quite different things, and they need different screens.
    ///
    /// Before setup it means the app cannot record yet, and the useful thing to show is what is
    /// still missing. After setup it means nothing has been recorded, and the useful thing to show
    /// is where recordings will land. Showing the second in the first case is how an app ends up
    /// telling someone their meetings will appear here when nothing would ever put one there.
    /// The library could not be read. Distinct from an empty one, and it says so.
    private func libraryFailure(_ error: String) -> some View {
        ContentUnavailableView {
            Label("Couldn’t open your meetings", systemImage: "exclamationmark.triangle")
        } description: {
            // Naming the saved files matters more than the error string does: the reassurance
            // people need first is that this is a reading problem, not a missing-data one.
            Text("\(error)\n\nYour saved meetings are still on this iPhone.")
        } actions: {
            Button("Try again") { store.library.reload() }
                .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder var emptyState: some View {
        if SetupState(store: store).isComplete {
            ContentUnavailableView {
                Label("No meetings yet", systemImage: "waveform")
            } description: {
                Text(
                    "Recordings you save show up here, and as markdown files in \(store.persistence.saveFolderDisplayName)."
                )
            }
        } else {
            ScrollView {
                SetupChecklist()
                    .padding(.horizontal, MobileTheme.Spacing.lg)
                    .padding(.top, MobileTheme.Spacing.lg)
                    .padding(.bottom, floatingControlInset)
            }
        }
    }

    // MARK: - Contents

    private var isSearchable: Bool {
        store.library.meetings.count > Self.searchThreshold
    }

    private var sections: [MeetingDaySection] {
        MeetingDaySection.sections(for: filteredMeetings)
    }

    /// The query is only honoured while the field is on screen — a library that shrinks back below
    /// the threshold takes the field away with it, and a filter left applied by a field the user
    /// can no longer see would look like meetings had gone missing.
    private var filteredMeetings: [Meeting] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isSearchable, !query.isEmpty else { return store.library.meetings }
        return store.library.meetings.filter { meeting in
            meeting.title.localizedStandardContains(query)
                || meeting.summary?.overview.localizedStandardContains(query) == true
        }
    }

    /// Names the file that's about to go, because "delete" alone doesn't say the markdown in the
    /// user's own folder goes with it.
    private var deletionMessage: String {
        let subject =
            pendingDeletion.count == 1
            ? "“\(pendingDeletion[0].title)”"
            : "These meetings"
        return
            "\(subject) and the markdown \(pendingDeletion.count == 1 ? "file" : "files") in \(store.persistence.saveFolderDisplayName) will be deleted. This can't be undone."
    }
}

/// One day's meetings under one heading.
///
/// Grouping and headings live outside the view because they are the only part of this screen with a
/// wrong answer — a meeting filed under the wrong day, or a heading that says "Monday" about two
/// different Mondays — and both can be checked without a view hierarchy.
struct MeetingDaySection: Identifiable {
    /// The start of the day, which is the section's identity and its sort key at once.
    let id: Date
    let title: String
    let meetings: [Meeting]

    static func sections(
        for meetings: [Meeting],
        relativeTo now: Date = Date(),
        calendar: Calendar = .current
    ) -> [MeetingDaySection] {
        let byDay = Dictionary(grouping: meetings) { calendar.startOfDay(for: $0.startedAt) }
        return byDay.keys.sorted(by: >).map { day in
            MeetingDaySection(
                id: day,
                title: heading(for: day, relativeTo: now, calendar: calendar),
                meetings: byDay[day, default: []].sorted { $0.startedAt > $1.startedAt }
            )
        }
    }

    /// "Today", "Yesterday", the weekday for the rest of the week, then the date.
    ///
    /// A weekday stops being an answer at seven days, where it starts meaning two different days,
    /// so that is where it gives way to a date. The year only shows up when it isn't this one.
    private static func heading(for day: Date, relativeTo now: Date, calendar: Calendar) -> String {
        let daysAgo = calendar.dateComponents([.day], from: day, to: calendar.startOfDay(for: now)).day ?? 0
        switch daysAgo {
        case 0: return "Today"
        case 1: return "Yesterday"
        case 2..<7: return day.formatted(.dateTime.weekday(.wide))
        default:
            return calendar.isDate(day, equalTo: now, toGranularity: .year)
                ? day.formatted(.dateTime.month(.wide).day())
                : day.formatted(.dateTime.month(.wide).day().year())
        }
    }
}
