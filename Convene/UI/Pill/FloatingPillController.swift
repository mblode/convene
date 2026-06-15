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
        // Re-anchor when displays are added/removed/rearranged (e.g. plugging in an external
        // monitor flips notch docking on/off).
        observers.append(center.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.reflow() }
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
        // Above the menu bar (`.statusBar` > `.mainMenu`) so the docked surface can visually
        // merge with the notch; `.fullScreenAuxiliary` keeps it visible over fullscreen Zoom/Meet.
        // Deliberately below `.screenSaver`/alert levels so we never sit over system dialogs.
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        // The SwiftUI content draws its own shadow over a transparent, padded window — a window
        // shadow would frame the whole transparent rect. Matches DynamicNotchKit.
        panel.hasShadow = false
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

        if screen.notchFrame != nil {
            // Docked: the panel's top edge meets the very top of the screen so the content's dark
            // connector merges with the notch hardware; the interactive pill hangs into the safe
            // area below the menu bar (HIG: keep controls out from behind the camera housing).
            let originY = full.maxY - size.height
            let originX = clampedX(center: full.midX, width: size.width, visible: visible)
            panel.setFrame(NSRect(x: originX, y: originY, width: size.width, height: size.height),
                           display: true, animate: false)
        } else {
            // Floating: a pill just below the menu bar, centered on the screen.
            let originY = visible.maxY - size.height - 6
            let originX = clampedX(center: full.midX, width: size.width, visible: visible)
            panel.setFrame(NSRect(x: originX, y: originY, width: size.width, height: size.height),
                           display: true, animate: false)
        }
    }

    /// Horizontal origin centered on `center`, kept fully on-screen with an 8pt inset.
    private func clampedX(center: CGFloat, width: CGFloat, visible: NSRect) -> CGFloat {
        let raw = center - width / 2
        return min(max(raw, visible.minX + 8), visible.maxX - width - 8)
    }

    /// The screen to host the pill: prefer the built-in notched display (the pill's natural home),
    /// else the active/main screen.
    private func preferredScreen() -> NSScreen {
        NSScreen.screens.first(where: \.hasNotch) ?? NSScreen.main ?? NSScreen.screens[0]
    }

    var isNotchDocked: Bool {
        preferredScreen().notchFrame != nil
    }

    /// Vertical inset reserved at the top of the docked content for the notch/menu-bar band, so
    /// the interactive pill sits in the safe area below it. Zero when floating.
    var notchTopInset: CGFloat {
        let screen = preferredScreen()
        return screen.notchFrame != nil ? screen.menubarHeight : 0
    }
}

/// Borderless non-activating panels can't become key by default, which blocks text input in the
/// capture field. Allowing it lets the field accept typing without activating the whole app.
private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
