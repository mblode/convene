import SwiftUI
import UIKit

@main
struct ConveneMobileApp: App {
    @StateObject private var store = MobileMeetingStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .task { store.prepare() }
                // A meeting outlasts the screen timeout, and the audio background mode keeps
                // capture alive when the phone locks — but a screen that sleeps mid-meeting also
                // hides the elapsed timer and the stop button, so keep it awake while recording.
                .onChange(of: store.isRecording, initial: true) { _, recording in
                    UIApplication.shared.isIdleTimerDisabled = recording
                }
                // Microphone access can be flipped in iOS Settings, which sends the user back
                // here without any view re-appearing. Re-read it whenever we come forward.
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { store.recorder.refreshPermission() }
                }
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            RecordingView()
                .tabItem { Label("Record", systemImage: "mic.fill") }

            MeetingsView()
                .tabItem { Label("Meetings", systemImage: "list.bullet") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
