import SwiftUI

struct RecordingView: View {
    @EnvironmentObject var store: MobileMeetingStore

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if store.transcriber.isConnecting {
                    loadingContent
                } else if store.isRecording {
                    recordingContent
                } else {
                    idleContent
                }
            }
            .navigationTitle("Convene")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Loading state

    private var loadingContent: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Text("Connecting to AssemblyAI...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Cloud transcription starts when the connection is ready")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding()
    }

    // MARK: - Idle state

    private var idleContent: some View {
        VStack(spacing: 32) {
            Spacer()

            if let summary = store.currentSummary {
                summaryCard(summary)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("Tap to start recording")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            recordButton(size: 72)
            statusText
        }
        .padding()
    }

    // MARK: - Recording state

    private var recordingContent: some View {
        VStack(spacing: 0) {
            TextField("Meeting title", text: $store.meetingTitle)
                .font(.headline)
                .textFieldStyle(.plain)
                .padding(.horizontal)
                .padding(.vertical, 12)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        if store.transcriber.segments.isEmpty {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Listening...")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityLabel("Listening for speech")
                        }

                        ForEach(store.transcriber.segments) { segment in
                            TranscriptRow(segment: segment)
                                .id(segment.id)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .onChange(of: store.transcriber.segments.count) {
                    if let last = store.transcriber.segments.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            Divider()

            recordingToolbar
        }
    }

    private var recordingToolbar: some View {
        HStack(spacing: 16) {
            Button {
                store.toggleRecording()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 44, height: 44)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white)
                        .frame(width: 16, height: 16)
                }
            }
            .accessibilityLabel("Stop and save recording")

            TimelineView(.periodic(from: .now, by: 1)) { context in
                if let start = store.meetingStartedAt {
                    let elapsed = Int(context.date.timeIntervalSince(start))
                    Text(String(format: "%02d:%02d", elapsed / 60, elapsed % 60))
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)
                .opacity(0.8)

            Spacer()

            Button("Cancel", role: .destructive) {
                store.cancelRecording()
            }
            .font(.subheadline)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.bar)
    }

    // MARK: - Shared components

    private func recordButton(size: CGFloat) -> some View {
        Button {
            store.toggleRecording()
        } label: {
            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: size, height: size)
                Image(systemName: "mic.fill")
                    .font(.system(size: size * 0.35))
                    .foregroundStyle(.white)
            }
        }
        .disabled(store.isToggling)
        .accessibilityLabel("Start recording")
    }

    private var statusText: some View {
        Text(store.status)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
            .padding(.bottom, 16)
    }

    @ViewBuilder
    private func summaryCard(_ summary: MeetingSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last meeting summary")
                .font(.headline)

            Text(summary.overview)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !summary.keyPoints.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Key points")
                        .font(.caption)
                        .fontWeight(.semibold)
                    ForEach(summary.keyPoints, id: \.self) { point in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•")
                            Text(point)
                        }
                        .font(.caption)
                    }
                }
                .accessibilityElement(children: .combine)
            }

            if !summary.decisions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Decisions")
                        .font(.caption)
                        .fontWeight(.semibold)
                    ForEach(summary.decisions, id: \.self) { decision in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•")
                            Text(decision)
                        }
                        .font(.caption)
                    }
                }
                .accessibilityElement(children: .combine)
            }

            if !summary.actionItems.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Action items")
                        .font(.caption)
                        .fontWeight(.semibold)
                    ForEach(summary.actionItems, id: \.self) { item in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "square")
                                .font(.caption2)
                            Text(item)
                        }
                        .font(.caption)
                    }
                }
                .accessibilityElement(children: .combine)
            }

            if !summary.openQuestions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Open questions")
                        .font(.caption)
                        .fontWeight(.semibold)
                    ForEach(summary.openQuestions, id: \.self) { question in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•")
                            Text(question)
                        }
                        .font(.caption)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct TranscriptRow: View {
    let segment: TranscriptSegment

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(segment.speaker.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(speakerColor)
                Text(segment.formattedTimestamp)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Text(segment.text)
                .font(.subheadline)
                .opacity(segment.isFinal ? 1 : 0.6)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(segment.speaker.displayName), \(segment.formattedTimestamp), \(segment.text)")
    }

    private var speakerColor: Color {
        switch segment.speaker {
        case .you: .blue
        case .others: .green
        case .named: .orange
        }
    }
}
