import AppKit
import Combine
import SwiftUI

/// A borderless, non-activating panel that floats over any app (Zoom/Meet/Teams) while a meeting
/// is recording — the product's signature active-session surface. Hosts the record state + timer,
/// the `⌘K` key-moment capture field, and the `⌘?` live recap.
///
/// Presentation adapts to hardware: on notched MacBooks it docks snug under the notch with a flat
/// top edge (Dynamic-Island-style); elsewhere it's a free-floating pill below the menu bar. Both
/// are the same state machine — only `notchDocked` and the anchor change.
@MainActor
final class FloatingPillController {
    static let shared = FloatingPillController()

    private weak var meetingStore: MeetingStore?
    private let model = FloatingPillModel()

    private var panel: NSPanel?
    private var captureCancellable: AnyCancellable?
    private var modeCancellable: AnyCancellable?
    private var observers: [NSObjectProtocol] = []

    /// Width budget per mode; height sizes to the SwiftUI content.
    private static let collapsedWidth: CGFloat = 250
    private static let captureWidth: CGFloat = 340
    private static let recapWidth: CGFloat = 380

    private init() {}

    func configure(meetingStore: MeetingStore) {
        self.meetingStore = meetingStore
    }

    /// Begins observing recording state and hotkey notifications. The pill auto-shows while a
    /// meeting records and tears down when it stops.
    func install() {
        guard let meetingStore else { return }

        captureCancellable = meetingStore.captureCoordinator.$isCapturing
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] capturing in
                if capturing { self?.showPill() } else { self?.dismiss() }
            }

        // Reposition when the expanded content changes the panel's size.
        modeCancellable = model.$mode
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in self?.reflow() }

        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .conveneFlagKeyMoment, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.flagAndCapture() }
        })
        observers.append(center.addObserver(forName: .conveneLiveRecap, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.toggleRecap() }
        })
    }

    // MARK: - Hotkey actions

    /// `⌘K`: flag a moment immediately (so a bare flag always lands), then open the capture field
    /// to optionally annotate it. No-op when not recording.
    func flagAndCapture() {
        guard let meetingStore, meetingStore.isRecording else { return }
        showPill()
        if let moment = meetingStore.flagKeyMoment() {
            model.pendingMomentID = moment.id
            model.captureText = ""
            model.mode = .capture
            focusPanel()
        } else {
            confirmFlag()
        }
    }

    /// `⌘?`: toggle the recap surface. No-op when not recording.
    func toggleRecap() {
        guard let meetingStore, meetingStore.isRecording else { return }
        showPill()
        if model.mode == .recap {
            model.mode = .collapsed
            return
        }
        model.mode = .recap
        meetingStore.requestLiveRecap()
        focusPanel()
    }

    func collapse() {
        model.mode = .collapsed
        model.pendingMomentID = nil
        model.captureText = ""
    }

    /// Commits the capture field's text onto the moment flagged when capture opened.
    func commitCapture() {
        if let id = model.pendingMomentID {
            meetingStore?.annotateKeyMoment(id: id, text: model.captureText)
        }
        collapse()
    }

    private func confirmFlag() {
        model.flashFlagConfirmation = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            self.model.flashFlagConfirmation = false
        }
    }

    // MARK: - Panel lifecycle

    private func showPill() {
        guard let meetingStore else { return }
        if panel == nil {
            panel = makePanel(meetingStore: meetingStore)
        }
        guard let panel else { return }
        if !panel.isVisible {
            model.mode = .collapsed
            panel.orderFrontRegardless()
        }
        reflow()
    }

    func dismiss() {
        collapse()
        panel?.orderOut(nil)
    }

    private func makePanel(meetingStore: MeetingStore) -> NSPanel {
        let host = NSHostingController(
            rootView: FloatingPillView(controller: self)
                .environmentObject(meetingStore)
                .environmentObject(model)
        )
        host.sizingOptions = [.preferredContentSize]

        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.collapsedWidth, height: 44),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = host
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        return panel
    }

    /// Brings the panel to key so the capture field / recap can take keyboard focus, without
    /// stealing the meeting app's foreground (non-activating panel).
    private func focusPanel() {
        panel?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Layout & notch docking

    /// Re-sizes to fit the current mode and re-anchors below the menu bar (or under the notch).
    private func reflow() {
        guard let panel, panel.isVisible else { return }
        // Let SwiftUI settle the new fitting size before measuring/anchoring.
        DispatchQueue.main.async { [weak self] in
            guard let self, let panel = self.panel, panel.isVisible else { return }
            let fitting = panel.contentViewController?.view.fittingSize ?? .zero
            let width = max(self.targetWidth, fitting.width)
            let height = max(44, fitting.height)
            self.anchor(panel: panel, size: NSSize(width: width, height: height))
        }
    }

    private var targetWidth: CGFloat {
        switch model.mode {
        case .collapsed: return Self.collapsedWidth
        case .capture: return Self.captureWidth
        case .recap: return Self.recapWidth
        }
    }

    private func anchor(panel: NSPanel, size: NSSize) {
        let screen = preferredScreen()
        let visible = screen.visibleFrame
        let full = screen.frame

        // Snug to the menu bar: 2pt below the visible-area top. When docked at the notch the pill's
        // top edge meets the menu bar so it reads as hanging from the notch.
        let topGap: CGFloat = notchFrame(on: screen) != nil ? 0 : 6
        let originY = visible.maxY - size.height - topGap

        let centerX: CGFloat
        if let notch = notchFrame(on: screen) {
            centerX = notch.midX
        } else {
            centerX = full.midX
        }
        var originX = centerX - size.width / 2
        // Keep fully on-screen.
        originX = min(max(originX, visible.minX + 8), visible.maxX - size.width - 8)

        panel.setFrame(NSRect(x: originX, y: originY, width: size.width, height: size.height), display: true, animate: false)
    }

    /// The screen to host the pill: the one with the menu bar / key window, falling back to main.
    private func preferredScreen() -> NSScreen {
        NSScreen.main ?? NSScreen.screens.first ?? NSScreen.screens[0]
    }

    /// The notch's rect in screen coordinates on notched MacBooks, else nil. Derived from the
    /// auxiliary top areas flanking the notch (macOS 12+).
    private func notchFrame(on screen: NSScreen) -> NSRect? {
        guard screen.safeAreaInsets.top > 0 else { return nil }
        guard let left = screen.auxiliaryTopLeftArea,
              let right = screen.auxiliaryTopRightArea else { return nil }
        let notchWidth = right.minX - left.maxX
        guard notchWidth > 0 else { return nil }
        return NSRect(
            x: left.maxX,
            y: screen.frame.maxY - screen.safeAreaInsets.top,
            width: notchWidth,
            height: screen.safeAreaInsets.top
        )
    }

    var isNotchDocked: Bool {
        notchFrame(on: preferredScreen()) != nil
    }
}

/// Borderless non-activating panels can't become key by default, which blocks text input in the
/// capture field. Allowing it lets the field accept typing without activating the whole app.
private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
