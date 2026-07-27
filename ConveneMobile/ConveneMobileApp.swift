import SwiftUI
import UIKit

@main
struct ConveneMobileApp: App {
    @StateObject private var store = MobileMeetingStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .task { store.prepare() }
                // The audio background mode keeps capture alive when the phone locks, but a screen
                // that sleeps mid-meeting also hides the elapsed timer and the stop button — so
                // keep it awake for as long as a meeting is running.
                .onChange(of: store.isRecording, initial: true) { _, recording in
                    UIApplication.shared.isIdleTimerDisabled = recording
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
        // The transcript is the one view long enough to read for minutes at a time, so let the tab
        // bar shrink out of the way while scrolling down and come back on the way up.
        .minimizingTabBar()
    }
}
