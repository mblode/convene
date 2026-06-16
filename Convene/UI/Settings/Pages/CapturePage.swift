import SwiftUI

struct CapturePage: View {
    @EnvironmentObject var meetingStore: MeetingStore
    @AppStorage(AudioCaptureCoordinator.reduceSpeakerBleedKey) private var reduceSpeakerBleed = true

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
            PageTitle("Capture")

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionLabel("Detection")
                SettingsCard {
                    SettingsRow(
                        icon: "app.badge",
                        title: "Auto-detect meeting apps",
                        description: "Notifies when Zoom, Teams, Webex, Meet, BlueJeans launch",
                        showsDivider: true
                    ) {
                        Toggle("", isOn: Binding(
                            get: { meetingStore.meetingDetector.enabled },
                            set: { meetingStore.meetingDetector.enabled = $0 }
                        ))
                        .toggleStyle(OliveToggleStyle())
                        .labelsHidden()
                    }
                    SettingsRow(
                        icon: "stop.circle",
                        title: "Auto-stop when meeting ends",
                        description: "Stops recording once you quit the last open meeting app",
                        showsDivider: shouldShowLastDetected
                    ) {
                        Toggle("", isOn: Binding(
                            get: { meetingStore.meetingDetector.autoStopOnMeetingEnd },
                            set: { meetingStore.meetingDetector.autoStopOnMeetingEnd = $0 }
                        ))
                        .toggleStyle(OliveToggleStyle())
                        .labelsHidden()
                        .disabled(!meetingStore.meetingDetector.enabled)
                    }
                    if shouldShowLastDetected {
                        SettingsRow(
                            icon: "clock.arrow.circlepath",
                            title: "Last detected",
                            description: meetingStore.meetingDetector.lastDetectedApp ?? "None yet",
                            showsDivider: false
                        ) {}
                    }
                }
                Text("Browser-based meetings (Meet/Zoom Web) aren't detected yet.")
                    .font(.captionWarm)
                    .foregroundStyle(Color.textSecondary)
                    .padding(.horizontal, 4)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionLabel("Audio")
                SettingsCard {
                    SettingsRow(
                        icon: "speaker.wave.2.fill",
                        title: "Reduce speaker bleed",
                        description: "Drops mic audio that's just the remote speaker playing through your speakers",
                        showsDivider: false
                    ) {
                        Toggle("", isOn: $reduceSpeakerBleed)
                            .toggleStyle(OliveToggleStyle())
                            .labelsHidden()
                    }
                }
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionLabel("Debug")
                SettingsCard {
                    SettingsRow(
                        icon: "ant",
                        title: "Save raw audio (WAV)",
                        description: "Writes mic and system-audio captures to the app's temporary folder",
                        showsDivider: false
                    ) {
                        Toggle("", isOn: $meetingStore.saveDebugWAVs)
                            .toggleStyle(OliveToggleStyle())
                            .labelsHidden()
                    }
                }
            }
        }
        .padding(.top, Theme.Spacing.xl)
    }

    private var shouldShowLastDetected: Bool {
        meetingStore.meetingDetector.enabled && meetingStore.meetingDetector.lastDetectedApp != nil
    }
}
