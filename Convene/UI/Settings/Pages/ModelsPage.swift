import SwiftUI

struct ModelsPage: View {
    @EnvironmentObject var meetingStore: MeetingStore
    @State private var showAPIKeyPopover = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
            PageTitle("Models")

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionLabel("Transcription")
                SettingsCard {
                    SettingsRow(
                        icon: "waveform.badge.mic",
                        title: "Engine",
                        description: "Cloud transcription through your OpenAI API key",
                        showsDivider: false
                    ) {
                        Text("OpenAI Realtime")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionLabel("Summary")
                SettingsCard {
                    Button {
                        showAPIKeyPopover = true
                    } label: {
                        SettingsRow(
                            icon: "key.fill",
                            title: "OpenAI API key",
                            description: meetingStore.hasAPIKey ? "Saved to Keychain" : "Required for transcription and summaries"
                        ) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.textTertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showAPIKeyPopover, arrowEdge: .trailing) {
                        APIKeyPopover(isPresented: $showAPIKeyPopover)
                            .environmentObject(meetingStore)
                    }
                    SettingsRow(
                        icon: "text.append",
                        title: "Generate summary after each meeting",
                        description: "Runs once recording stops"
                    ) {
                        Toggle("", isOn: $meetingStore.generateSummaryAfterMeeting)
                            .toggleStyle(OliveToggleStyle())
                            .labelsHidden()
                    }
                    SettingsRow(
                        icon: "sparkles",
                        title: "Summary model",
                        description: "Used when summary is generated",
                        showsDivider: false,
                        isDisabled: !meetingStore.generateSummaryAfterMeeting
                    ) {
                        Picker("", selection: $meetingStore.summaryModel) {
                            Text("gpt-5.5").tag("gpt-5.5")
                            Text("gpt-5.4-mini").tag("gpt-5.4-mini")
                            Text("gpt-5.4-nano").tag("gpt-5.4-nano")
                            Text("gpt-4o-mini").tag("gpt-4o-mini")
                            Text("gpt-4o").tag("gpt-4o")
                            Text("gpt-4.1-mini").tag("gpt-4.1-mini")
                            Text("gpt-4.1").tag("gpt-4.1")
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(minWidth: 140)
                        .disabled(!meetingStore.generateSummaryAfterMeeting)
                    }
                }
            }
        }
        .padding(.top, Theme.Spacing.xl)
    }
}
