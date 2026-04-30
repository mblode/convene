import AppKit
import SwiftUI

struct MeetingWindow: View {
    enum RightPane: String, Hashable, CaseIterable {
        case notes = "Notes"
        case summary = "Summary"
    }

    @EnvironmentObject var meetingStore: MeetingStore
    @State private var autoScroll: Bool = true
    @State private var rightPane: RightPane = .notes
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 0) {
            header
            DashedDivider()
            HSplitView {
                transcriptPane
                    .frame(minWidth: 320, idealWidth: 420)
                notesPane
                    .frame(minWidth: 320)
            }
            footer
        }
        .frame(minWidth: 720, minHeight: 480)
        .background(Color.appBackground)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            recordingDot

            TextField("Meeting title", text: $meetingStore.meetingTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                Text("Auto-scroll")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
                Toggle("", isOn: $autoScroll)
                    .toggleStyle(OliveToggleStyle())
                    .labelsHidden()
            }

            Button {
                meetingStore.toggleRecording()
            } label: {
                Text(meetingStore.captureCoordinator.isCapturing ? "Stop" : "Start")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(meetingStore.captureCoordinator.isCapturing ? Color.recordingRed : Color.accentOlive)
                    )
            }
            .buttonStyle(.plain)
            .keyboardShortcut("r", modifiers: [.command])
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var recordingDot: some View {
        ZStack {
            if meetingStore.captureCoordinator.isCapturing {
                Circle()
                    .fill(Color.recordingRed.opacity(0.25))
                    .frame(width: 18, height: 18)
                    .scaleEffect(pulse ? 1.4 : 0.9)
                    .opacity(pulse ? 0 : 0.6)
                    .animation(.easeOut(duration: 1.2).repeatForever(autoreverses: false), value: pulse)
            }
            Circle()
                .fill(meetingStore.captureCoordinator.isCapturing ? Color.recordingRed : Color.textTertiary)
                .frame(width: 10, height: 10)
        }
        .frame(width: 18, height: 18)
        .onAppear { pulse = true }
    }

    // MARK: - Transcript pane

    private var transcriptPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            paneTitle("Transcript")
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        if meetingStore.transcriptionCoordinator.segments.isEmpty {
                            transcriptEmptyState
                        } else {
                            ForEach(meetingStore.transcriptionCoordinator.segments) { segment in
                                TranscriptSegmentRow(segment: segment)
                                    .id(segment.id)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: meetingStore.transcriptionCoordinator.segments.count) { _, _ in
                    guard autoScroll, let last = meetingStore.transcriptionCoordinator.segments.last else { return }
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var transcriptEmptyState: some View {
        VStack(spacing: 14) {
            IconBadge(systemName: "waveform", size: 44, iconSize: 20, tint: Color.textSecondary)
            Text("Transcript will appear here when you start recording.")
                .foregroundStyle(Color.textSecondary)
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Notes / Summary pane

    private var notesPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            paneSwitcher
            switch rightPane {
            case .notes:
                TextEditor(text: $meetingStore.meetingNotes)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
            case .summary:
                summaryView
            }
        }
    }

    private var paneSwitcher: some View {
        HStack {
            Picker("", selection: $rightPane) {
                ForEach(RightPane.allCases, id: \.self) { pane in
                    Text(pane.rawValue).tag(pane)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 220)

            Spacer()

            if rightPane == .summary, meetingStore.summaryService.isGenerating {
                ProgressView()
                    .controlSize(.small)
                Text("Generating…")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var summaryView: some View {
        if let summary = meetingStore.currentSummary {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if !summary.overview.isEmpty {
                        Text(summary.overview)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textPrimary)
                            .textSelection(.enabled)
                    }
                    summarySection(title: "Key points", items: summary.keyPoints, glyph: "circle.fill")
                    summarySection(title: "Decisions", items: summary.decisions, glyph: "checkmark.circle.fill")
                    summarySection(title: "Action items", items: summary.actionItems, glyph: "square")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else if meetingStore.summaryService.isGenerating {
            VStack(spacing: 12) {
                ProgressView()
                Text("Summarizing transcript…")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 14) {
                IconBadge(systemName: "sparkles", size: 44, iconSize: 20, tint: Color.accentOlive)
                Text("Stop the meeting to generate a summary.")
                    .foregroundStyle(Color.textSecondary)
                    .font(.system(size: 13))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 60)
        }
    }

    @ViewBuilder
    private func summarySection(title: String, items: [String], glyph: String) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
                    .textCase(.uppercase)
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 9) {
                        Image(systemName: glyph)
                            .font(.system(size: 7))
                            .foregroundStyle(Color.accentOlive)
                            .frame(width: 12, alignment: .center)
                            .offset(y: -2)
                        Text(item)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textPrimary)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 10) {
            Text(meetingStore.captureStatus)
                .font(.system(size: 12))
                .foregroundStyle(Color.textSecondary)

            Spacer()

            if let savedURL = meetingStore.lastSavedURL {
                Button {
                    meetingStore.persistence.revealInFinder(savedURL)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 11))
                        Text(savedURL.lastPathComponent)
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(Color.textSecondary)
                }
                .buttonStyle(.plain)
            }

            if meetingStore.persistence.outputFolderURL == nil {
                Button("Choose output folder…") {
                    meetingStore.chooseOutputFolderAndRetrySave()
                }
                .buttonStyle(.borderless)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.accentOlive)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(Color.sidebarBackground)
        .overlay(alignment: .top) {
            DashedDivider()
        }
    }

    private func paneTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.textSecondary)
            .textCase(.uppercase)
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 6)
    }
}

private struct TranscriptSegmentRow: View {
    let segment: TranscriptSegment

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(segment.speaker.displayName.lowercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(speakerColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(speakerColor.opacity(0.12), in: Capsule())
                .frame(width: 72, alignment: .center)

            VStack(alignment: .leading, spacing: 4) {
                Text(segment.text.isEmpty ? "…" : segment.text)
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
        case .you:    return Color.accentOlive
        case .others: return Color.textSecondary
        }
    }

    private var timestampLabel: String {
        let mm = Int(segment.startedAt) / 60
        let ss = Int(segment.startedAt) % 60
        return String(format: "%02d:%02d", mm, ss)
    }
}
