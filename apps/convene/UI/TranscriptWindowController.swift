import AppKit
import Combine
import SwiftUI

/// Owns the transcript window. A window rather than the popover because the popover closes on
/// the first click elsewhere, and the transcript is read alongside the call.
@MainActor
final class TranscriptWindowController {
    static let shared = TranscriptWindowController()

    private weak var meetingStore: MeetingStore?
    private var windowController: NSWindowController?
    private var levelCancellable: AnyCancellable?

    private init() {}

    func configure(meetingStore: MeetingStore) {
        self.meetingStore = meetingStore
    }

    func show() {
        guard let meetingStore else {
            logError("TranscriptWindowController: not configured")
            return
        }

        if windowController == nil {
            let host = NSHostingController(
                rootView: LiveTranscriptView().environmentObject(meetingStore)
            )
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 440, height: 560),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Transcript"
            window.contentViewController = host
            window.isReleasedWhenClosed = false
            // Opens on the Space in use, including over a full-screen call, rather than
            // switching the reader away from the call to wherever the window was last.
            window.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
            // Center first: setting the autosave name restores a saved frame, and the window is
            // usually parked beside the call, so it should reopen where it was left.
            window.center()
            window.setFrameAutosaveName("ConveneTranscriptWindow")
            windowController = NSWindowController(window: window)

            // Floats while recording, like Live Captions, so clicking into the call doesn't bury
            // it. Once the recording stops it's a document to copy from, and stacks like one.
            levelCancellable = meetingStore.captureCoordinator.$isCapturing
                .receive(on: DispatchQueue.main)
                .sink { [weak window] isCapturing in
                    window?.level = isCapturing ? .floating : .normal
                }
        }

        NSApp.activate(ignoringOtherApps: true)
        windowController?.showWindow(nil)
        windowController?.window?.makeKeyAndOrderFront(nil)
    }
}
