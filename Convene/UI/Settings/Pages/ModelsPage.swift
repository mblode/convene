import SwiftUI

struct ModelsPage: View {
    @EnvironmentObject var meetingStore: MeetingStore

    private var usesAnthropic: Bool { meetingStore.summaryProvider == "anthropic" }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
            PageTitle("Models")

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionLabel("Transcription")
                SettingsCard {
                    SettingsRow(
                        icon: "waveform.badge.mic",
                        title: "Engine",
                        description: "Cloud transcription through your AssemblyAI API key"
                    ) {
                        Text("AssemblyAI Universal-3 Pro Streaming")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textSecondary)
                    }
                    APIKeyRow(provider: .assemblyAI, showsDivider: false)
                }
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionLabel("Summary")
                SettingsCard {
                    APIKeyRow(provider: .openAI)
                    APIKeyRow(provider: .anthropic)
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
                        icon: "building.2",
                        title: "Summary provider",
                        description: "Anthropic (Claude) is recommended",
                        isDisabled: !meetingStore.generateSummaryAfterMeeting
                    ) {
                        Picker("", selection: $meetingStore.summaryProvider) {
                            Text("Anthropic").tag("anthropic")
                            Text("OpenAI").tag("openai")
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(minWidth: 140)
                        .disabled(!meetingStore.generateSummaryAfterMeeting)
                    }
                    SettingsRow(
                        icon: "sparkles",
                        title: "Summary model",
                        description: "Used when summary is generated",
                        showsDivider: false,
                        isDisabled: !meetingStore.generateSummaryAfterMeeting
                    ) {
                        if usesAnthropic {
                            Picker("", selection: $meetingStore.claudeSummaryModel) {
                                ForEach(SummaryModelCatalog.anthropic, id: \.self) { model in
                                    Text(model).tag(model)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(minWidth: 140)
                            .disabled(!meetingStore.generateSummaryAfterMeeting)
                        } else {
                            Picker("", selection: $meetingStore.summaryModel) {
                                ForEach(SummaryModelCatalog.openAI, id: \.self) { model in
                                    Text(model).tag(model)
                                }
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
        .padding(.top, Theme.Spacing.xl)
    }
}

/// A settings row that opens the API-key popover for one provider, owning its own popover state.
private struct APIKeyRow: View {
    @EnvironmentObject var meetingStore: MeetingStore
    let provider: APIKeyPopover.Provider
    var showsDivider: Bool = true

    @State private var showPopover = false

    var body: some View {
        Button {
            showPopover = true
        } label: {
            SettingsRow(
                icon: "key.fill",
                title: provider.title,
                description: meetingStore[keyPath: provider.keyPath].hasKey
                    ? "Saved to Keychain"
                    : provider.requiredDescription,
                showsDivider: showsDivider
            ) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPopover, arrowEdge: .trailing) {
            APIKeyPopover(isPresented: $showPopover, provider: provider)
                .environmentObject(meetingStore)
        }
    }
}
