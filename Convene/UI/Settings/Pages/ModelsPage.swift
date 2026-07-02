import SwiftUI

struct ModelsPage: View {
    @EnvironmentObject var meetingStore: MeetingStore
    @State private var showAPIKeyPopover = false
    @State private var showClaudeAPIKeyPopover = false
    @State private var showAssemblyAIKeyPopover = false

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
                    Button {
                        showAssemblyAIKeyPopover = true
                    } label: {
                        SettingsRow(
                            icon: "key.fill",
                            title: "AssemblyAI API key",
                            description: meetingStore.assemblyAIKeyField.hasKey ? "Saved to Keychain" : "Required for transcription",
                            showsDivider: false
                        ) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.textTertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showAssemblyAIKeyPopover, arrowEdge: .trailing) {
                        APIKeyPopover(isPresented: $showAssemblyAIKeyPopover, provider: .assemblyAI)
                            .environmentObject(meetingStore)
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
                            description: meetingStore.openAIKeyField.hasKey ? "Saved to Keychain" : "Required for OpenAI summaries"
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
                        APIKeyPopover(isPresented: $showAPIKeyPopover, provider: .openAI)
                            .environmentObject(meetingStore)
                    }
                    Button {
                        showClaudeAPIKeyPopover = true
                    } label: {
                        SettingsRow(
                            icon: "key.fill",
                            title: "Anthropic API key",
                            description: meetingStore.claudeKeyField.hasKey ? "Saved to Keychain" : "Required for Claude summaries"
                        ) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.textTertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showClaudeAPIKeyPopover, arrowEdge: .trailing) {
                        APIKeyPopover(isPresented: $showClaudeAPIKeyPopover, provider: .anthropic)
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
                                Text("claude-fable-5").tag("claude-fable-5")
                                Text("claude-opus-4-8").tag("claude-opus-4-8")
                                Text("claude-sonnet-4-6").tag("claude-sonnet-4-6")
                                Text("claude-haiku-4-5").tag("claude-haiku-4-5")
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(minWidth: 140)
                            .disabled(!meetingStore.generateSummaryAfterMeeting)
                        } else {
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
        }
        .padding(.top, Theme.Spacing.xl)
    }
}
