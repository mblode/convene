import SwiftUI

/// The main screen: start/stop, the live transcript, and the notes you type while it runs.
struct RecordingView: View {
    @EnvironmentObject private var store: MobileMeetingStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Drives the elapsed timer. Only updated while recording.
    @State private var now = Date()

    /// Discard throws away the whole in-flight meeting — transcript, notes, key moments — and the
    /// write-ahead log with it, so there's nothing left to recover from afterwards. It sits one tap
    /// away from the key-moment button people are reaching for mid-meeting without looking.
    @State private var isConfirmingDiscard = false

    private static let bottomAnchor = "transcript-bottom"
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// True once there's something to scroll: a running meeting, a transcript, or a finished
    /// summary. Until then the screen is just the button, and it belongs in the middle.
    private var hasContent: Bool {
        store.isRecording || !store.transcriber.segments.isEmpty || store.currentSummary != nil
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: MobileTheme.Spacing.xl) {
                        if let banner = store.banner {
                            BannerView(text: banner.text, isError: banner.isError)
                                .transition(.opacity)
                        }

                        if hasContent {
                            recordControls
                            titleAndNotes
                            transcriptSection
                            summarySection
                        } else {
                            recordControls
                                .containerRelativeFrame(.vertical, alignment: .center)
                        }

                        Color.clear.frame(height: 1).id(Self.bottomAnchor)
                    }
                    .padding(MobileTheme.Spacing.lg)
                    .animation(reduceMotion ? nil : MobileTheme.Motion.standard, value: hasContent)
                    .animation(reduceMotion ? nil : MobileTheme.Motion.standard, value: store.isRecording)
                }
                .onChange(of: store.transcriber.segments.count) { _, _ in
                    guard store.isRecording else { return }
                    withAnimation(reduceMotion ? nil : MobileTheme.Motion.standard) {
                        proxy.scrollTo(Self.bottomAnchor, anchor: .bottom)
                    }
                }
            }
            .navigationTitle("Convene")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .softScrollEdges()
        }
        .onReceive(ticker) { date in
            // Only while recording — otherwise an idle screen re-renders once a second for a timer
            // nobody is looking at.
            if store.isRecording { now = date }
        }
        // Starting and stopping a recording are the two commitments worth confirming through the
        // hand, since the phone is often face down by then.
        .sensoryFeedback(trigger: store.isRecording) { _, recording in
            recording ? .start : .stop
        }
        .sensoryFeedback(.success, trigger: store.keyMoments.count)
        .sensoryFeedback(.error, trigger: store.banner?.isError == true)
        .confirmationDialog(
            "Discard this recording?",
            isPresented: $isConfirmingDiscard,
            titleVisibility: .visible
        ) {
            Button("Discard recording", role: .destructive) { store.cancelRecording() }
            Button("Keep recording", role: .cancel) {}
        } message: {
            Text(
                "The transcript and any key moments from this meeting will be thrown away. Stop instead if you want to keep them."
            )
        }
    }

    // MARK: - Controls

    private var recordControls: some View {
        VStack(spacing: MobileTheme.Spacing.md) {
            RecordButton(
                isRecording: store.isRecording,
                isBusy: store.isToggling,
                isInterrupted: store.isInterrupted,
                levelMeter: store.recorder.levelMeter,
                action: store.toggleRecording
            )

            if store.isRecording {
                elapsedReadout
                liveActions
            } else {
                Text(
                    "Put the phone on the table and tap to record. Convene transcribes as it goes and writes a note when you stop."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// No separate blinking dot beside this. The ring around the button is already the live
    /// indicator, and it's a better one — it moves with the actual input, so it distinguishes
    /// "recording and hearing the room" from "recording silence", which a dot on a timer can't.
    private var elapsedReadout: some View {
        Text(elapsedText)
            // The running time is the primary readout once a meeting starts, so it gets the weight
            // to match. Rounded digits and slightly tightened tracking keep a widening number from
            // drifting apart as it grows.
            .font(.system(.largeTitle, design: .rounded).monospacedDigit())
            .tracking(-0.5)
            .contentTransition(.numericText())
            .foregroundStyle(store.isInterrupted ? .secondary : .primary)
            .accessibilityLabel("Recording, \(elapsedText) elapsed")
    }

    private var liveActions: some View {
        VStack(spacing: MobileTheme.Spacing.sm) {
            // Side by side until the labels stop fitting, then stacked. At accessibility text sizes
            // a fixed row truncates these to "Key…" and "Disc…", and "Discard" is not a control to
            // leave people guessing at mid-meeting.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: MobileTheme.Spacing.md) {
                    keyMomentButton
                    discardButton
                }
                VStack(spacing: MobileTheme.Spacing.sm) {
                    keyMomentButton
                    discardButton
                }
            }

            if !store.keyMoments.isEmpty {
                Text("\(store.keyMoments.count) key moment\(store.keyMoments.count == 1 ? "" : "s") flagged")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
        }
    }

    private var keyMomentButton: some View {
        Button {
            store.flagKeyMoment()
        } label: {
            Label("Key moment", systemImage: "flag.fill")
        }
        .glassActionButton()
        // Glass renders labels in the default foreground, which left these two buttons looking
        // identical — the tint is what carries "routine" versus "destructive" now.
        .tint(.accentColor)
    }

    private var discardButton: some View {
        Button(role: .destructive) {
            isConfirmingDiscard = true
        } label: {
            Label("Discard", systemImage: "trash")
        }
        .glassActionButton()
        .tint(.recordingRed)
    }

    private var elapsedText: String {
        guard let started = store.meetingStartedAt else { return "00:00" }
        return TranscriptFormatter.timestampString(max(0, now.timeIntervalSince(started)))
    }

    // MARK: - Fields

    @ViewBuilder
    private var titleAndNotes: some View {
        if store.isRecording {
            VStack(alignment: .leading, spacing: MobileTheme.Spacing.lg) {
                field("Title") {
                    TextField("Untitled meeting", text: $store.meetingTitle)
                        .textFieldStyle(.roundedBorder)
                }
                field("Your notes") {
                    TextEditor(text: $store.meetingNotes)
                        .frame(minHeight: 90)
                        .scrollContentBackground(.hidden)
                        .padding(MobileTheme.Spacing.xs)
                        .background(
                            Color(.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: MobileTheme.Radius.card)
                        )
                }
            }
            .transition(.opacity)
        }
    }

    private func field(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: MobileTheme.Spacing.xs) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    // MARK: - Results

    @ViewBuilder
    private var transcriptSection: some View {
        if !store.transcriber.segments.isEmpty {
            VStack(alignment: .leading, spacing: MobileTheme.Spacing.md) {
                Text("Transcript").font(.headline)
                TranscriptView(segments: store.transcriber.segments)
            }
        } else if store.isRecording {
            HStack(spacing: MobileTheme.Spacing.sm) {
                ProgressView().controlSize(.small)
                Text("Listening…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var summarySection: some View {
        if let summary = store.currentSummary, !store.isRecording {
            SummaryView(summary: summary)
                .transition(.opacity)
        }
    }
}
