import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// The root screen's empty state, and the app's real onboarding.
///
/// A modal tour would be read once and forgotten; the work it describes outlives it. So the
/// remaining setup lives here instead, on the screen the user lands on, ticking off as they go —
/// and the card is simply gone once a meeting can be recorded.
///
/// Present it gated on `SetupState`, so the card leaves no gap behind it in a stack:
///
/// ```swift
/// let setup = SetupState(store: store)
/// if !setup.isComplete { SetupChecklist() }
/// ```
struct SetupChecklist: View {
    @EnvironmentObject private var store: MobileMeetingStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL

    @State private var isEnteringKey = false
    @State private var isPickingFolder = false

    private var setup: SetupState { SetupState(store: store) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            rows
        }
        // Clipped before the surface is drawn so a pressed first or last row can't paint its
        // rectangle over the card's rounded corners.
        .clipShape(RoundedRectangle(cornerRadius: MobileTheme.Radius.card))
        .cardSurface()
        .animation(reduceMotion ? nil : MobileTheme.Motion.quiet, value: setup)
        .sheet(isPresented: $isEnteringKey) { APIKeySheet() }
        .fileImporter(isPresented: $isPickingFolder, allowedContentTypes: [.folder]) { result in
            switch result {
            case .success(let url):
                store.persistence.handlePickedFolder(url)
            case .failure(let error):
                logError("SetupChecklist: folder pick failed: \(error.localizedDescription)")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: MobileTheme.Spacing.xs) {
            Text("Set up Convene")
                .typeStyle(.cardTitle)
                .foregroundStyle(Color.textPrimary)

            Text(headerDetail)
                .typeStyle(.caption)
                .foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(MobileTheme.Spacing.lg)
        .accessibilityElement(children: .combine)
    }

    /// Names the one thing actually in the way. The card only appears when something is, and a
    /// fixed line would claim the key was missing on the day the microphone was switched off.
    private var headerDetail: String {
        setup.hasTranscriptionKey
            ? "Convene needs the microphone back before it can record."
            : "One key is all that stands between here and a recorded meeting."
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: 0) {
            SetupRow(
                status: setup.transcriptionKeyStatus,
                title: "Add your AssemblyAI key",
                detail: setup.hasTranscriptionKey
                    ? "Saved to your iPhone’s Keychain."
                    : "Convene transcribes through AssemblyAI, so it can’t hear anything without one.",
                action: { isEnteringKey = true }
            )

            divider

            microphoneRow

            divider

            SetupRow(
                status: setup.folderStatus,
                kicker: "Optional",
                title: "Choose where notes are saved",
                detail: setup.hasChosenFolder
                    ? "Saving to \(store.persistence.saveFolderDisplayName)."
                    : "Meetings save to \(store.persistence.saveFolderDisplayName) until you point Convene at an Obsidian vault or another folder.",
                action: { isPickingFolder = true }
            )
        }
    }

    /// No action when the permission is merely unasked.
    ///
    /// iOS raises the microphone prompt once and never again, so it is spent at the first record
    /// tap — the only moment the request explains itself. A button here would spend it on a row
    /// nobody asked for, and leave a denial that only iPhone Settings can undo.
    @ViewBuilder
    private var microphoneRow: some View {
        switch setup.microphone {
        case .granted:
            SetupRow(status: .done, title: "Allow the microphone", detail: "Convene can hear the room.")

        case .undetermined:
            SetupRow(
                status: .waiting,
                title: "Allow the microphone",
                detail: "iOS asks the first time you record. Nothing to do here."
            )

        case .denied:
            SetupRow(
                status: .blocked,
                title: "Allow the microphone",
                detail: "Microphone access is off for Convene. Turn it back on in iPhone Settings.",
                action: {
                    guard let settings = URL(string: UIApplication.openSettingsURLString) else { return }
                    openURL(settings)
                }
            )
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.dividerWarm)
            .frame(height: 1)
            .padding(.leading, MobileTheme.Spacing.lg)
    }
}

/// One line of the checklist: a status mark, what to do, and why.
private struct SetupRow: View {
    let status: SetupStepStatus
    var kicker: String? = nil
    let title: String
    let detail: String
    var action: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let action {
            Button(action: action) { content }
                .buttonStyle(PressableStyle(Rectangle()))
                .accessibilityValue(accessibilityValue)
                .accessibilityAddTraits(status == .done ? .isSelected : [])
        } else {
            content
                .accessibilityElement(children: .combine)
                .accessibilityValue(accessibilityValue)
                .accessibilityAddTraits(status == .done ? .isSelected : [])
        }
    }

    private var content: some View {
        HStack(alignment: .top, spacing: MobileTheme.Spacing.md) {
            statusMark

            VStack(alignment: .leading, spacing: MobileTheme.Spacing.xs) {
                if let kicker {
                    Text(kicker)
                        .typeStyle(.chip)
                        .foregroundStyle(Color.textTertiary)
                }

                Text(title)
                    .typeStyle(.bodyEmphasis)
                    .foregroundStyle(status == .done ? Color.textSecondary : Color.textPrimary)

                Text(detail)
                    .typeStyle(.caption)
                    .foregroundStyle(status == .blocked ? Color.recordingRed : Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if action != nil {
                Image(systemName: "chevron.right")
                    .imageScale(.small)
                    .foregroundStyle(Color.textTertiary)
                    .accessibilityHidden(true)
            }
        }
        .multilineTextAlignment(.leading)
        .padding(MobileTheme.Spacing.lg)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    private var statusMark: some View {
        Image(systemName: symbolName)
            .imageScale(.large)
            .foregroundStyle(markTint)
            .accessibilityHidden(true)
            .contentTransition(markTransition)
    }

    /// `.replace` cross-fades the glyph in place; without it the tick pops in hard while the row's
    /// text is still settling, which is the one moment in this card worth softening.
    private var markTransition: ContentTransition {
        reduceMotion ? .identity : .symbolEffect(.replace)
    }

    private var symbolName: String {
        switch status {
        case .done: "checkmark.circle.fill"
        case .waiting: "circle"
        case .blocked: "exclamationmark.circle.fill"
        }
    }

    private var markTint: Color {
        switch status {
        case .done: .accent
        case .waiting: .textTertiary
        case .blocked: .recordingRed
        }
    }

    /// Spoken after the row's label, so completion doesn't rest on a glyph VoiceOver would
    /// otherwise read as "checkmark circle fill" or skip entirely.
    private var accessibilityValue: String {
        switch status {
        case .done: "Done"
        case .waiting: "Not done"
        case .blocked: "Needs attention"
        }
    }
}

/// The AssemblyAI key on its own, with the one thing the field can't say: where to get a key.
///
/// Presented by the checklist's first row, and directly by the record button when someone taps it
/// without a key — a banner there would only name the problem, and this is the fix.
struct APIKeySheet: View {
    @EnvironmentObject private var store: MobileMeetingStore
    @Environment(\.dismiss) private var dismiss

    private static let dashboard = URL(string: "https://www.assemblyai.com/dashboard/api-keys")!

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MobileTheme.Spacing.xl) {
                    APIKeyRow(
                        title: "AssemblyAI",
                        placeholder: "Your AssemblyAI key…",
                        footnote: "Required for transcription.",
                        field: $store.assemblyAIKeyField
                    )
                    .padding(MobileTheme.Spacing.lg)
                    .cardSurface()

                    VStack(alignment: .leading, spacing: MobileTheme.Spacing.sm) {
                        Text("Where to find one")
                            .typeStyle(.section)
                            .foregroundStyle(Color.textPrimary)

                        Text(
                            "Sign in to AssemblyAI and copy the key from your dashboard. New accounts start with free credit, which covers a good few meetings."
                        )
                        .typeStyle(.body)
                        .foregroundStyle(Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                        Link(destination: Self.dashboard) {
                            Text("assemblyai.com/dashboard/api-keys")
                                .typeStyle(.body)
                                .frame(minHeight: 44, alignment: .leading)
                        }
                    }

                    Text(
                        "Keys live in your iPhone’s Keychain. There’s no Convene server — audio goes to AssemblyAI, the transcript goes to your summary provider, and nowhere else."
                    )
                    .typeStyle(.caption)
                    .foregroundStyle(Color.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(MobileTheme.Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.appBackground)
            .navigationTitle("AssemblyAI key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        // `APIKeyRow` saves when its field loses focus, which a dismissal — by button or by drag —
        // isn't guaranteed to deliver first. Saving again here is idempotent, and it's the
        // difference between a pasted key surviving the sheet and vanishing with it.
        .onDisappear { store.assemblyAIKeyField.save() }
    }
}
