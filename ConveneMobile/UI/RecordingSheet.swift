import SwiftUI

/// The live meeting: what it's called, what you're typing, what it's hearing, and the two things
/// you do while it runs.
///
/// **This sheet is presentation only.** The lifecycle lives in `RecordingSession`, and dismissing a
/// sheet is a statement about a sheet — so a swipe down, a tap outside, or anything else that
/// closes this leaves the meeting running and the record pill carrying it. Nothing here may stop or
/// discard a recording except the two controls that say so on the label. Wiring a stop into
/// `onDisappear` would mean a stray swipe ends someone's meeting, which is the one failure this
/// screen can't come back from.
struct RecordingSheet: View {
    @EnvironmentObject private var store: MobileMeetingStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Field { case title, notes }

    @State private var detent: PresentationDetent = .medium
    @State private var hasExpandedForTranscript = false

    /// Discard throws away the whole in-flight meeting — transcript, notes, key moments — and the
    /// write-ahead log with it, so there's nothing left to recover from afterwards. That is why it
    /// lives in the overflow menu behind a confirmation, and not next to the key-moment button
    /// people are reaching for mid-meeting without looking.
    @State private var isConfirmingDiscard = false

    @FocusState private var focus: Field?

    private static let bottomAnchor = "transcript-bottom"

    /// True once there's something here worth scrolling. Until then the sheet is an explainer and a
    /// button, and those belong centred in it rather than pinned to its top edge.
    private var hasContent: Bool {
        store.isRecording || !store.transcriber.segments.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: MobileTheme.Spacing.xl) {
                        if let banner = store.banner {
                            BannerView(text: banner.text, isError: banner.isError)
                                .transition(.opacity)
                        }

                        if hasContent {
                            header
                            liveReadout
                            notesField
                            transcriptSection
                        } else {
                            explainer
                                .containerRelativeFrame(.vertical, alignment: .center)
                        }

                        Color.clear.frame(height: 1).id(Self.bottomAnchor)
                    }
                    .padding(.horizontal, MobileTheme.Spacing.lg)
                    .padding(.vertical, MobileTheme.Spacing.lg)
                    .animation(reduceMotion ? nil : MobileTheme.Motion.standard, value: hasContent)
                }
                .onChange(of: store.transcriber.segments.count) { _, count in
                    guard store.isRecording else { return }
                    promoteForFirstTranscript(count)
                    withAnimation(reduceMotion ? nil : MobileTheme.Motion.standard) {
                        proxy.scrollTo(Self.bottomAnchor, anchor: .bottom)
                    }
                }
            }

            controlBar
        }
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        // Half height is a deliberate half: the meetings list stays visible and usable underneath,
        // so checking an older note doesn't mean leaving the meeting. Bounded at `.medium` because
        // at full height the sheet covers the list anyway, and letting taps through to something
        // nobody can see is how you tap the wrong thing.
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        // Without this, dragging the transcript from rest resizes the sheet instead of scrolling
        // it, which makes a long transcript unreadable at the medium detent.
        .presentationContentInteraction(.scrolls)
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: focus) { _, field in
            // A medium sheet is shorter than the keyboard, so typing into it means typing behind
            // the keyboard. Grow first, then let the field come up.
            guard field != nil else { return }
            withAnimation(reduceMotion ? nil : MobileTheme.Motion.sheet) { detent = .large }
        }
        .onChange(of: store.isRecording) { _, isRecording in
            // Stop and Discard both end the meeting and leave nothing here to look at — except a
            // failure, whose message needs the sheet to stay put long enough to be read.
            guard !isRecording, store.banner?.isError != true else { return }
            dismiss()
        }
        // Starting and stopping a recording are the two commitments worth confirming through the
        // hand, since the phone is often face down by then.
        .sensoryFeedback(trigger: store.isRecording) { _, recording in
            recording ? .start : .stop
        }
        .sensoryFeedback(.success, trigger: store.keyMoments.count)
        // Only on the way into an error — the bare `trigger:` form buzzes when one clears too.
        .sensoryFeedback(trigger: store.banner?.isError == true) { _, isError in
            isError ? .error : nil
        }
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

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: MobileTheme.Spacing.md) {
            // Placeholder-led rather than labelled: "Untitled meeting" says what the field is and
            // what it will be called if you never touch it, which a "Title" caption above an empty
            // box does not. `axis: .vertical` lets a long title wrap instead of scrolling out of
            // sight one character at a time.
            TextField("Untitled meeting", text: $store.meetingTitle, axis: .vertical)
                .typeStyle(.cardTitle)
                .foregroundStyle(Color.textPrimary)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.done)
                .focused($focus, equals: .title)
                .accessibilityLabel("Meeting title")

            if store.isRecording {
                overflowMenu
            }
        }
    }

    private var overflowMenu: some View {
        Menu {
            Button(role: .destructive) {
                isConfirmingDiscard = true
            } label: {
                Label("Discard recording", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .imageScale(.large)
                .foregroundStyle(Color.textSecondary)
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .accessibilityLabel("More options")
    }

    // MARK: - Live readout

    @ViewBuilder
    private var liveReadout: some View {
        if store.isRecording {
            VStack(spacing: MobileTheme.Spacing.lg) {
                ElapsedTimeText(startedAt: store.meetingStartedAt)
                    .typeStyle(.timer)
                    // Dimmed while another app holds the microphone: the clock keeps counting, but
                    // it isn't counting anything being heard, and it shouldn't claim to be.
                    .foregroundStyle(store.isInterrupted ? Color.textSecondary : Color.textPrimary)

                LevelMeter(
                    meter: store.recorder.levelMeter,
                    isActive: !store.isInterrupted,
                    tint: .recordingRed,
                    size: .expanded
                )
            }
            .frame(maxWidth: .infinity)
            .transition(.opacity)
        }
    }

    // MARK: - Notes

    @ViewBuilder
    private var notesField: some View {
        if store.isRecording {
            // A `TextField` with a vertical axis rather than a `TextEditor`: it comes with the
            // placeholder, grows with what you type, and sits on the page instead of inside a box,
            // which is what keeps this reading as one continuous note.
            TextField("Write your notes here…", text: $store.meetingNotes, axis: .vertical)
                .typeStyle(.body)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(3...)
                .focused($focus, equals: .notes)
                .accessibilityLabel("Your notes")
                .transition(.opacity)
        }
    }

    // MARK: - Transcript

    @ViewBuilder
    private var transcriptSection: some View {
        if !store.transcriber.segments.isEmpty {
            VStack(alignment: .leading, spacing: MobileTheme.Spacing.lg) {
                Divider().overlay(Color.cardBorder)
                TranscriptView(segments: store.transcriber.segments)
            }
        } else if store.isRecording {
            HStack(spacing: MobileTheme.Spacing.sm) {
                ProgressView().controlSize(.small)
                Text("Listening…")
                    .typeStyle(.caption)
                    .foregroundStyle(Color.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var explainer: some View {
        Text(
            "Put the phone on the table and start recording. Convene transcribes as it goes and writes a note when you stop."
        )
        .typeStyle(.body)
        .foregroundStyle(Color.textSecondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Controls

    /// Pinned below the scroll rather than inside it. Key moment and Stop are the reasons this
    /// sheet exists, and neither should ever need scrolling to.
    private var controlBar: some View {
        VStack(spacing: MobileTheme.Spacing.sm) {
            if store.isRecording {
                liveControls

                if !store.keyMoments.isEmpty {
                    Text(
                        "\(store.keyMoments.count) key moment\(store.keyMoments.count == 1 ? "" : "s") flagged"
                    )
                    .typeStyle(.caption)
                    .foregroundStyle(Color.textSecondary)
                    .contentTransition(.numericText())
                }
            } else {
                startButton
            }
        }
        .padding(MobileTheme.Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(.bar)
        .overlay(alignment: .top) { Divider().overlay(Color.cardBorder) }
    }

    private var liveControls: some View {
        // Side by side until the labels stop fitting, then stacked. At accessibility text sizes a
        // fixed row truncates these to "Key…" and "St…", and neither is a control to leave people
        // guessing at mid-meeting.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: MobileTheme.Spacing.md) {
                keyMomentButton
                stopButton
            }
            VStack(spacing: MobileTheme.Spacing.sm) {
                keyMomentButton
                stopButton
            }
        }
    }

    /// The big one. It's pressed repeatedly, usually without looking, often with the phone flat on
    /// a table — so it takes the width, the prominent fill, and the distance from anything that
    /// ends the meeting.
    private var keyMomentButton: some View {
        Button {
            store.flagKeyMoment()
        } label: {
            Label("Key moment", systemImage: "flag.fill")
                .typeStyle(.bodyEmphasis)
                .padding(.horizontal, MobileTheme.Spacing.lg)
                .frame(maxWidth: .infinity, minHeight: 56)
        }
        .glassActionButton(isProminent: true)
        .tint(.accent)
        .accessibilityHint("Marks this moment in the transcript")
    }

    private var stopButton: some View {
        Button {
            store.toggleRecording()
        } label: {
            Label("Stop", systemImage: "stop.fill")
                .typeStyle(.bodyEmphasis)
                .padding(.horizontal, MobileTheme.Spacing.lg)
                .frame(minHeight: 56)
        }
        .glassActionButton()
        // Glass renders labels in the default foreground, so the tint is what carries "this is the
        // one that ends the meeting" without making it destructive-looking — Stop saves.
        .tint(.recordingRed)
        .disabled(store.isToggling)
        .accessibilityHint("Ends the meeting and saves the note")
    }

    private var startButton: some View {
        Button {
            store.toggleRecording()
        } label: {
            HStack(spacing: MobileTheme.Spacing.sm) {
                if store.isToggling {
                    // Starting is the slow one — microphone permission, then the transcriber's
                    // websocket — and silence for two seconds reads as a button that missed.
                    ProgressView()
                    Text("Starting…")
                } else {
                    Image(systemName: "record.circle.fill")
                    Text("Start recording")
                }
            }
            .typeStyle(.bodyEmphasis)
            .padding(.horizontal, MobileTheme.Spacing.lg)
            .frame(maxWidth: .infinity, minHeight: 56)
        }
        .glassActionButton(isProminent: true)
        .tint(.recordingRed)
        .disabled(store.isToggling)
    }

    /// Grows the sheet the first time someone speaks, and only that once. After the promotion the
    /// detent belongs to the user — a sheet that springs back to full height every time a new turn
    /// lands is one you cannot push out of the way.
    private func promoteForFirstTranscript(_ segmentCount: Int) {
        guard !hasExpandedForTranscript, segmentCount > 0 else { return }
        hasExpandedForTranscript = true
        withAnimation(reduceMotion ? nil : MobileTheme.Motion.sheet) { detent = .large }
    }
}
