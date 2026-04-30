import SwiftUI

struct CapturePage: View {
    @EnvironmentObject var meetingStore: MeetingStore

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            PageTitle("Capture")

            VStack(alignment: .leading, spacing: 12) {
                SectionLabel("Detection")
                SettingsCard {
                    SettingsRow(
                        icon: "app.badge",
                        title: "Auto-detect meeting apps",
                        description: "Notifies when Zoom, Teams, Webex, Slack, Meet, BlueJeans launch",
                        showsDivider: shouldShowLastDetected
                    ) {
                        Toggle("", isOn: Binding(
                            get: { meetingStore.meetingDetector.enabled },
                            set: { meetingStore.meetingDetector.enabled = $0 }
                        ))
                        .toggleStyle(OliveToggleStyle())
                        .labelsHidden()
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

            VStack(alignment: .leading, spacing: 12) {
                SectionLabel("Debug")
                SettingsCard {
                    SettingsRow(
                        icon: "ant",
                        title: "Save raw audio (WAV) to /tmp",
                        description: "Useful for verifying mic + system-audio capture independently of transcription",
                        showsDivider: false
                    ) {
                        Toggle("", isOn: $meetingStore.saveDebugWAVs)
                            .toggleStyle(OliveToggleStyle())
                            .labelsHidden()
                    }
                }
            }
        }
    }

    private var shouldShowLastDetected: Bool {
        meetingStore.meetingDetector.enabled && meetingStore.meetingDetector.lastDetectedApp != nil
    }
}
