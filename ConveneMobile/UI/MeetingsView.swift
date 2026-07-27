import SwiftUI

/// Every meeting Convene has saved on this phone, newest first.
struct MeetingsView: View {
    @EnvironmentObject private var store: MobileMeetingStore

    var body: some View {
        NavigationStack {
            Group {
                if store.library.meetings.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Meetings")
        }
        .onAppear { store.library.reload() }
    }

    private var list: some View {
        List {
            if let error = store.library.lastError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(Color.recordingRed)
            }

            ForEach(store.library.meetings) { meeting in
                NavigationLink(value: meeting.id) {
                    MeetingRow(meeting: meeting)
                }
            }
            .onDelete { offsets in
                for meeting in offsets.map({ store.library.meetings[$0] }) {
                    store.deleteMeeting(meeting)
                }
            }
        }
        // Routing by id rather than by value: the summary lands a few seconds after the meeting
        // is saved, and looking the meeting up on each render means an open detail view picks it
        // up instead of showing the copy that was pushed.
        .navigationDestination(for: UUID.self) { id in
            if let meeting = store.library.meetings.first(where: { $0.id == id }) {
                MeetingDetailView(meeting: meeting)
            } else {
                ContentUnavailableView("Meeting not found", systemImage: "questionmark.folder")
            }
        }
        .refreshable { store.library.reload() }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No meetings yet", systemImage: "waveform")
        } description: {
            Text("Recordings you save show up here, and as markdown files in \(store.persistence.saveFolderDisplayName).")
        }
    }
}

private struct MeetingRow: View {
    let meeting: Meeting

    var body: some View {
        VStack(alignment: .leading, spacing: MobileTheme.Spacing.xs) {
            Text(meeting.title)
                .font(.body.weight(.medium))
                .lineLimit(2)

            HStack(spacing: MobileTheme.Spacing.sm) {
                Text(meeting.startedAt, format: .dateTime.weekday().day().month().hour().minute())
                if let duration = durationText {
                    Text("·")
                    Text(duration)
                }
                if !meeting.keyMoments.isEmpty {
                    Text("·")
                    Label("\(meeting.keyMoments.count)", systemImage: "flag.fill")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let overview = meeting.summary?.overview, !overview.isEmpty {
                Text(overview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, MobileTheme.Spacing.xs)
    }

    private var durationText: String? {
        guard let ended = meeting.endedAt else { return nil }
        let minutes = Int((ended.timeIntervalSince(meeting.startedAt) / 60).rounded(.up))
        guard minutes > 0 else { return nil }
        return "\(minutes) min"
    }
}
