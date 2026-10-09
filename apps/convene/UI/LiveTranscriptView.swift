import AppKit
import SwiftUI

/// The current meeting's transcript as it streams in, in its own window so it can sit beside the
/// call. One selectable document: drag across turns and ⌘C, or Copy Transcript for the whole
/// thing in the shape the saved meeting exports.
struct LiveTranscriptView: View {
    @EnvironmentObject var meetingStore: MeetingStore

    /// Merged once per change of the segments, not once per render: the store republishes for
    /// every capture, calendar and settings change as well.
    @State private var blocks: [TranscriptFormatter.Block] = []
    @State private var isPinnedToBottom = true
    @State private var jumpRequest = 0
    @State private var didCopy = false
    @State private var copyResetTask: Task<Void, Never>?

    private var segments: [TranscriptSegment] { meetingStore.transcriber.segments }
    private var isCapturing: Bool { meetingStore.captureCoordinator.isCapturing }

    var body: some View {
        VStack(spacing: 0) {
            if blocks.isEmpty {
                emptyState
            } else {
                transcript
            }
            // The menu bar header's status line, repeated here: while this window is up, it's
            // where the reader is looking when transcription drops or a turn fails.
            if let banner = meetingStore.headerBanner {
                Text(banner.text)
                    .font(.system(size: 12))
                    .foregroundStyle(banner.isError ? Color.recordingRed : Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .overlay(alignment: .top) { Divider().opacity(0.5) }
            }
            bottomBar
        }
        .frame(minWidth: 320, minHeight: 240)
        .background(Color.appBackground)
        .onChange(of: segments, initial: true) { _, latest in
            blocks = TranscriptFormatter.mergedBlocks(latest)
            // The next recording's text view starts at the end; don't carry the old position over.
            if blocks.isEmpty { isPinnedToBottom = true }
        }
    }

    private var transcript: some View {
        let context = meetingStore.recordingContext
        return TranscriptTextView(
            blocks: blocks,
            selfName: context?.selfName,
            othersName: context?.othersName,
            isPinnedToBottom: $isPinnedToBottom,
            jumpRequest: jumpRequest
        )
        .overlay(alignment: .bottom) {
            // Scrolling back stops following; this says turns are still arriving below.
            if isCapturing && !isPinnedToBottom {
                Button {
                    jumpRequest += 1
                } label: {
                    Label("Jump to Latest", systemImage: "arrow.down")
                }
                .controlSize(.small)
                .padding(.bottom, Theme.Spacing.sm)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            if isCapturing {
                ProgressView().controlSize(.small)
                Text("Listening…")
            } else {
                // Only reachable after a recording that stopped before anyone was transcribed:
                // this window opens from a recording, and the next one clears the transcript.
                Image(systemName: "text.quote")
                    .font(.system(size: 22))
                    .foregroundStyle(.tertiary)
                Text("No speech was transcribed.")
            }
        }
        .font(.system(size: 13))
        .foregroundStyle(Color.textSecondary)
        .multilineTextAlignment(.center)
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: Theme.Spacing.sm) {
            if isCapturing {
                PulsingDot(color: .recordingRed)
                Text("Recording")
            } else if !blocks.isEmpty {
                Text("Recording stopped")
            }
            Spacer(minLength: Theme.Spacing.sm)
            Button(action: copyTranscript) {
                // Sized to the longer label, so "Copied" doesn't pull the button out from under
                // the pointer.
                ZStack {
                    Label("Copy Transcript", systemImage: "doc.on.doc").hidden()
                    Label(
                        didCopy ? "Copied" : "Copy Transcript",
                        systemImage: didCopy ? "checkmark" : "doc.on.doc"
                    )
                }
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .disabled(blocks.isEmpty)
            .help("Copy the whole transcript (⇧⌘C)")
        }
        .font(.system(size: 12))
        .foregroundStyle(Color.textSecondary)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .overlay(alignment: .top) {
            Divider().opacity(0.5)
        }
    }

    private func copyTranscript() {
        let context = meetingStore.recordingContext
        let text = MeetingTextExport.transcript(
            segments,
            selfName: context?.selfName,
            othersName: context?.othersName
        )
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        AccessibilityNotification.Announcement("Transcript copied").post()

        didCopy = true
        copyResetTask?.cancel()
        copyResetTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1500))
            guard !Task.isCancelled else { return }
            didCopy = false
        }
    }
}
