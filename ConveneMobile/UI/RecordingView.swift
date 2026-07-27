import SwiftUI

/// The main screen: start/stop, the live transcript, and the notes you type while it runs.
struct RecordingView: View {
    @EnvironmentObject private var store: MobileMeetingStore

    /// Drives the elapsed timer. Only updated while recording.
    @State private var now = Date()

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: MobileTheme.Spacing.xl) {
                        if let banner = store.banner {
                            BannerView(text: banner.text, isError: banner.isError)
                        }

                        recordControls

                        if store.isRecording {
                            titleField
                            notesField
                        }

                        if !store.transcriber.segments.isEmpty {
                            transcriptSection
                        } else if store.isRecording {
                            waitingForSpeech
                        }

                        if let summary = store.currentSummary, !store.isRecording {
                            SummaryView(summary: summary)
                        }

                        Color.clear.frame(height: 1).id(Self.bottomAnchor)
                    }
                    .padding(MobileTheme.Spacing.lg)
                }
                .onChange(of: store.transcriber.segments.count) { _, _ in
                    guard store.isRecording else { return }
                    withAnimation { proxy.scrollTo(Self.bottomAnchor, anchor: .bottom) }
                }
            }
            .navigationTitle("Convene")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
        }
        .onReceive(ticker) { date in
            // Only while recording — otherwise an idle screen re-renders once a second for a
            // timer nobody is looking at.
            if store.isRecording { now = date }
        }
    }

    private static let bottomAnchor = "transcript-bottom"

    // MARK: - Controls

    private var recordControls: some View {
        VStack(spacing: MobileTheme.Spacing.md) {
            Button {
                store.toggleRecording()
            } label: {
                ZStack {
                    Circle()
                        .fill(store.isRecording ? Color.recordingRed.opacity(0.15) : Color.accentColor.opacity(0.15))
                    if store.isToggling {
                        ProgressView()
                    } else {
                        Image(systemName: store.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(store.isRecording ? Color.recordingRed : Color.accentColor)
                    }
                }
                .frame(width: MobileTheme.recordButtonSize, height: MobileTheme.recordButtonSize)
            }
            .buttonStyle(.plain)
            .disabled(store.isToggling)
            .accessibilityLabel(store.isRecording ? "Stop recording" : "Start recording")

            if store.isRecording {
                HStack(spacing: MobileTheme.Spacing.sm) {
                    PulsingDot(isActive: !store.isInterrupted)
                    Text(elapsedText)
                        .font(.title3.monospacedDigit())
                        .contentTransition(.numericText())
                }

                HStack(spacing: MobileTheme.Spacing.md) {
                    Button {
                        store.flagKeyMoment()
                    } label: {
                        Label("Key moment", systemImage: "flag.fill")
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive) {
                        store.cancelRecording()
                    } label: {
                        Label("Discard", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }

                if !store.keyMoments.isEmpty {
                    Text("\(store.keyMoments.count) key moment\(store.keyMoments.count == 1 ? "" : "s") flagged")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Put the phone on the table and tap to record. Convene transcribes as it goes and writes a note when you stop.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        // The phone is usually face down or across the table when a moment gets flagged, so the
        // haptic is the only confirmation the user actually gets.
        .sensoryFeedback(.success, trigger: store.keyMoments.count)
    }

    private var elapsedText: String {
        let elapsed = store.meetingStartedAt.map { max(0, now.timeIntervalSince($0)) } ?? 0
        return TranscriptFormatter.timestampString(elapsed)
    }

    // MARK: - Fields

    private var titleField: some View {
        VStack(alignment: .leading, spacing: MobileTheme.Spacing.xs) {
            Text("Title")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField("Untitled meeting", text: $store.meetingTitle)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var notesField: some View {
        VStack(alignment: .leading, spacing: MobileTheme.Spacing.xs) {
            Text("Your notes")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextEditor(text: $store.meetingNotes)
                .frame(minHeight: 90)
                .padding(MobileTheme.Spacing.xs)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: MobileTheme.Radius.card))
                .scrollContentBackground(.hidden)
        }
    }

    // MARK: - Transcript

    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: MobileTheme.Spacing.md) {
            Text("Transcript")
                .font(.headline)
            TranscriptView(segments: store.transcriber.segments)
        }
    }

    private var waitingForSpeech: some View {
        HStack(spacing: MobileTheme.Spacing.sm) {
            ProgressView().controlSize(.small)
            Text("Listening…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

/// The status line above the record button: capture failures, transcription warnings, and the
/// transient connecting/summarising states.
struct BannerView: View {
    let text: String
    let isError: Bool

    var body: some View {
        HStack(alignment: .top, spacing: MobileTheme.Spacing.sm) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "info.circle.fill")
            Text(text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.footnote)
        .foregroundStyle(isError ? Color.recordingRed : Color.secondary)
        .padding(MobileTheme.Spacing.md)
        .background(
            (isError ? Color.recordingRed.opacity(0.1) : Color(.secondarySystemBackground)),
            in: RoundedRectangle(cornerRadius: MobileTheme.Radius.card)
        )
    }
}
