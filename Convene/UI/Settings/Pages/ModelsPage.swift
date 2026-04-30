import SwiftUI

struct ModelsPage: View {
    @EnvironmentObject var meetingStore: MeetingStore
    @State private var showAPIKeyPopover = false

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            PageTitle("Models")

            VStack(alignment: .leading, spacing: 12) {
                SectionLabel("OpenAI")
                SettingsCard {
                    SettingsRow(
                        icon: "key.fill",
                        title: "API key",
                        description: meetingStore.hasAPIKey ? "Saved to Keychain" : "Not set — required to transcribe",
                        showsDivider: false
                    ) {
                        Button { showAPIKeyPopover = true } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.textTertiary)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showAPIKeyPopover, arrowEdge: .trailing) {
                            APIKeyPopover(isPresented: $showAPIKeyPopover)
                                .environmentObject(meetingStore)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                SectionLabel("Transcription")
                SettingsCard {
                    SettingsRow(
                        icon: "waveform.badge.mic",
                        title: "Transcription model",
                        description: "Choose speed vs. quality"
                    ) {
                        Picker("", selection: $meetingStore.transcriptionModel) {
                            Text("gpt-4o-mini-transcribe").tag("gpt-4o-mini-transcribe")
                            Text("gpt-4o-transcribe").tag("gpt-4o-transcribe")
                            Text("whisper-1").tag("whisper-1")
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(minWidth: 180)
                    }
                    SettingsRow(
                        icon: "character.bubble",
                        title: "Language hint",
                        description: "Optional, e.g. \"en\" or \"es\"",
                        showsDivider: false
                    ) {
                        TextField("auto", text: $meetingStore.transcriptionLanguage)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                SectionLabel("Summary")
                SettingsCard {
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
    }
}
