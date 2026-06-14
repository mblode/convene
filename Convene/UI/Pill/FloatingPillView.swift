import SwiftUI

/// The floating pill's SwiftUI content. One view, three modes (collapsed / capture / recap) driven
/// by `FloatingPillModel`, matching the controller's notch-or-float presentation.
struct FloatingPillView: View {
    let controller: FloatingPillController
    @EnvironmentObject private var meetingStore: MeetingStore
    @EnvironmentObject private var model: FloatingPillModel

    @State private var now: Date = Date()
    @FocusState private var captureFocused: Bool
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            switch model.mode {
            case .collapsed: collapsedPill
            case .capture: capturePill
            case .recap: recapPanel
            }
        }
        .frame(width: contentWidth, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .themeShadow(Theme.Shadow.menu)
        .padding(6)
        .onReceive(tick) { now = $0 }
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: model.mode)
    }

    /// Fixed content width per mode so the self-sizing panel can measure a deterministic frame.
    /// Mirrors the controller's per-mode width budget.
    private var contentWidth: CGFloat {
        switch model.mode {
        case .collapsed: return 238
        case .capture: return 328
        case .recap: return 368
        }
    }

    /// Flat top corners when docked under the notch so the pill reads as hanging from it.
    private var cornerRadius: CGFloat { controller.isNotchDocked ? 14 : 16 }

    // MARK: - Collapsed

    private var collapsedPill: some View {
        HStack(spacing: 10) {
            recordingIndicator
            Spacer(minLength: 8)
            if model.flashFlagConfirmation {
                Label("Flagged", systemImage: "star.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.accent)
                    .transition(.opacity)
            }
            pillIconButton(system: "star", help: "Flag key moment (\(keyMomentHint))") {
                controller.flagAndCapture()
            }
            pillIconButton(system: "sparkles", help: "Live recap (\(recapHint))") {
                controller.toggleRecap()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .animation(.easeInOut(duration: 0.2), value: model.flashFlagConfirmation)
    }

    private var recordingIndicator: some View {
        HStack(spacing: 7) {
            PillPulse()
            Text(elapsedText)
                .font(.system(size: 13, weight: .medium).monospacedDigit())
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Capture

    private var capturePill: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.accent)
                Text("Key moment")
                    .font(.system(size: 12, weight: .semibold))
                Text(flaggedTimestamp)
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Text(elapsedText)
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(.tertiary)
            }

            TextField("What matters here?", text: $model.captureText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($captureFocused)
                .onSubmit { controller.commitCapture() }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )

            HStack(spacing: 4) {
                Text("⏎ Save")
                Text("·").foregroundStyle(.tertiary)
                Text("esc Keep flag")
            }
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(dismissKey)
        .onAppear { captureFocused = true }
    }

    // MARK: - Recap

    private var recapPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.accent)
                Text("Recap · last 2 min")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                if meetingStore.isGeneratingRecap {
                    ProgressView().controlSize(.small)
                }
                pillIconButton(system: "arrow.clockwise", help: "Refresh recap") {
                    meetingStore.requestLiveRecap()
                }
                pillIconButton(system: "xmark", help: "Close") {
                    controller.collapse()
                }
            }

            if let recap = meetingStore.liveRecap {
                Text(recap)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            let items = meetingStore.liveRecapTimeline()
            if items.isEmpty {
                Text("Nothing in the last couple of minutes yet.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(items) { item in
                            recapRow(item)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
        }
        .padding(14)
        .background(dismissKey)
    }

    @ViewBuilder
    private func recapRow(_ item: LiveRecap.Item) -> some View {
        switch item {
        case .moment(let moment):
            HStack(alignment: .top, spacing: 7) {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.accent)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 1) {
                    Text(moment.formattedTimestamp)
                        .font(.system(size: 10, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Color.accent)
                    if !moment.trimmedText.isEmpty {
                        Text(moment.trimmedText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                }
            }
        case .block(let block):
            VStack(alignment: .leading, spacing: 1) {
                Text(block.speaker.displayName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(block.text)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Invisible escape handler used by the expanded modes to collapse back to the pill.
    private var dismissKey: some View {
        Button("") { controller.collapse() }
            .keyboardShortcut(.cancelAction)
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
    }

    // MARK: - Bits

    private func pillIconButton(system: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var elapsedText: String {
        guard let start = meetingStore.meetingStartedAt else { return "0:00" }
        let total = max(0, Int(now.timeIntervalSince(start)))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    private var flaggedTimestamp: String {
        guard let id = model.pendingMomentID,
              let moment = meetingStore.keyMoments.first(where: { $0.id == id }) else { return "" }
        return moment.formattedTimestamp
    }

    private var keyMomentHint: String {
        let display = HotkeyManager.displayString(for: .flagKeyMoment)
        return display.isEmpty ? "⌥⇧K" : display
    }

    private var recapHint: String {
        let display = HotkeyManager.displayString(for: .liveRecap)
        return display.isEmpty ? "⌥⇧/" : display
    }
}

/// The pill's breathing record dot — a standalone copy so the pill doesn't depend on MenuBarView.
private struct PillPulse: View {
    @State private var pulsing = false
    var body: some View {
        Circle()
            .fill(Color.recordingRed)
            .frame(width: 8, height: 8)
            .opacity(pulsing ? 0.35 : 1)
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulsing)
            .onAppear { pulsing = true }
            .accessibilityHidden(true)
    }
}
