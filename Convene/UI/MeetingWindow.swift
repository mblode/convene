import AppKit
import SwiftUI

struct MeetingWindow: View {
    @EnvironmentObject var meetingStore: MeetingStore
    @State private var showTranscript = false

    var body: some View {
        VStack(spacing: 0) {
            header
            DashedDivider()
            noteSurface
            if showTranscript {
                transcriptDrawer
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            footer
        }
        .frame(minWidth: 720, minHeight: 480)
        .background(Color.appBackground)
        .animation(.easeInOut(duration: 0.16), value: showTranscript)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            recordingDot

            TextField("Meeting title", text: $meetingStore.meetingTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 20))
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                showTranscript.toggle()
            } label: {
                Label(showTranscript ? "Hide transcript" : "Transcript", systemImage: "text.bubble")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .fill(showTranscript ? Color.accentOliveSoft : Color.iconBadgeBackground)
            )

            Button {
                meetingStore.toggleRecording()
            } label: {
                Text(recordingButtonTitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
                    .frame(minWidth: 64)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                            .fill(meetingStore.captureCoordinator.isCapturing ? Color.recordingRed : Color.accentOlive)
                    )
            }
            .buttonStyle(.plain)
            .keyboardShortcut("r", modifiers: [.command])
            .disabled(meetingStore.isToggling)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var recordingButtonTitle: String {
        if meetingStore.isToggling { return "Working" }
        return meetingStore.captureCoordinator.isCapturing ? "Stop" : "Start"
    }

    private var recordingDot: some View {
        Circle()
            .fill(meetingStore.captureCoordinator.isCapturing ? Color.recordingRed : Color.textTertiary)
            .frame(width: 10, height: 10)
    }

    // MARK: - Notes

    private var noteSurface: some View {
        VStack(alignment: .leading, spacing: 12) {
            summaryStatus
            ZStack(alignment: .topLeading) {
                TextEditor(text: $meetingStore.meetingNotes)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if meetingStore.meetingNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Write notes here.")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.textTertiary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }
            }
            .background(Color.appBackground)
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var summaryStatus: some View {
        if meetingStore.summaryService.isGenerating {
            statusBanner(icon: "sparkles", text: "Generating summary for the saved note.")
        } else if let error = meetingStore.summaryService.lastError {
            statusBanner(icon: "exclamationmark.triangle", text: error, tint: Color.recordingRed)
        } else if meetingStore.currentSummary != nil {
            statusBanner(icon: "checkmark.circle", text: "Summary added to the saved note.")
        }
    }

    private func statusBanner(icon: String, text: String, tint: Color = Color.accentOlive) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(tint)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(Color.textSecondary)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                .fill(Color.iconBadgeBackground)
        )
    }

    // MARK: - Transcript

    private var transcriptDrawer: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Transcript")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textSecondary)
                    .textCase(.uppercase)
                Spacer()
                Text("\(meetingStore.transcriptionCoordinator.segments.count)")
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .padding(.bottom, 6)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if meetingStore.transcriptionCoordinator.segments.isEmpty {
                        Text("Transcript will appear here when recording starts.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                    } else {
                        ForEach(meetingStore.transcriptionCoordinator.segments) { segment in
                            TranscriptSegmentRow(segment: segment)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 12)
            }
        }
        .frame(maxHeight: 190)
        .background(Color.sidebarBackground)
        .overlay(alignment: .top) {
            DashedDivider()
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 10) {
            Text(meetingStore.captureStatus)
                .font(.system(size: 12))
                .foregroundStyle(Color.textSecondary)
                .lineLimit(1)

            Spacer()

            if let obsidianURL = meetingStore.persistence.lastObsidianFileURL {
                Button("Open Obsidian note") {
                    meetingStore.persistence.openFile(obsidianURL)
                }
                .buttonStyle(.borderless)
                .font(.system(size: 12))
                .foregroundStyle(Color.accentOlive)
            } else if let savedURL = meetingStore.lastSavedURL {
                Button("Open note") {
                    meetingStore.persistence.openFile(savedURL)
                }
                .buttonStyle(.borderless)
                .font(.system(size: 12))
                .foregroundStyle(Color.accentOlive)
            }

            if !meetingStore.persistence.hasConfiguredOutputFolder {
                Button("Choose folder") {
                    meetingStore.chooseOutputFolderAndRetrySave()
                }
                .buttonStyle(.borderless)
                .font(.system(size: 12))
                .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(Color.sidebarBackground)
        .overlay(alignment: .top) {
            DashedDivider()
        }
    }
}

private struct TranscriptSegmentRow: View {
    let segment: TranscriptSegment

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(segment.speaker.displayName.lowercased())
                .font(.system(size: 11))
                .foregroundStyle(speakerColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.cardBackground, in: Capsule())
                .frame(width: 72, alignment: .center)

            VStack(alignment: .leading, spacing: 4) {
                Text(segment.text.isEmpty ? "..." : segment.text)
                    .font(.system(size: 14))
                    .foregroundStyle(segment.isFinal ? Color.textPrimary : Color.textSecondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)

                Text(timestampLabel)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.textTertiary)
                    .monospacedDigit()
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.bubble, style: .continuous)
                .fill(Color.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.bubble, style: .continuous)
                .strokeBorder(Color.cardBorder, lineWidth: Theme.Stroke.hairline)
        )
    }

    private var speakerColor: Color {
        switch segment.speaker {
        case .you: return Color.accentOlive
        case .others: return Color.textSecondary
        }
    }

    private var timestampLabel: String {
        let mm = Int(segment.startedAt) / 60
        let ss = Int(segment.startedAt) % 60
        return String(format: "%02d:%02d", mm, ss)
    }
}
