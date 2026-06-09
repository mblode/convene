import AppKit
import Combine
import SwiftUI

/// Owns the menu bar status item and a free-floating `NSPanel` that hosts `MenuBarView`.
///
/// Replaces SwiftUI's `MenuBarExtra(.window)`, whose panel rendered flush against the menu bar and
/// clipped its own rounded top corners. Here the panel is a borderless floating window positioned a
/// few points *below* the menu bar, so the corners always render fully (the core fix). This mirrors
/// how polished menu bar apps (e.g. Granola) present their popovers.
@MainActor
final class StatusItemController {
    static let shared = StatusItemController()

    private weak var meetingStore: MeetingStore?
    private weak var hotkeyManager: HotkeyManager?

    private var statusItem: NSStatusItem?
    private var panel: NSPanel?
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var tintCancellable: AnyCancellable?

    /// Gap between the menu bar / status item and the top of the panel. This is what keeps the
    /// rounded top corners from clipping against the menu bar.
    private let topGap: CGFloat = 6

    private init() {}

    func configure(meetingStore: MeetingStore, hotkeyManager: HotkeyManager) {
        self.meetingStore = meetingStore
        self.hotkeyManager = hotkeyManager
    }

    func installStatusItem() {
        guard statusItem == nil, let meetingStore else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            let image = NSImage(named: "MenuBarIcon")
            image?.isTemplate = true
            button.image = image
            button.imageScaling = .scaleProportionallyDown
            button.target = self
            button.action = #selector(togglePanel)
            button.setAccessibilityLabel("Convene")
        }
        statusItem = item
        logInfo("StatusItem: installed (button=\(item.button != nil), image=\(item.button?.image != nil), target=\(item.button?.target != nil), action=\(item.button?.action?.description ?? "nil"))")

        // Tint the icon red while recording, matching the old MenuBarLabel's foregroundStyle.
        tintCancellable = meetingStore.captureCoordinator.$isCapturing
            .receive(on: RunLoop.main)
            .sink { [weak self] capturing in
                self?.statusItem?.button?.contentTintColor = capturing ? NSColor(Color.recordingRed) : nil
            }
        statusItem?.button?.contentTintColor = meetingStore.captureCoordinator.isCapturing
            ? NSColor(Color.recordingRed)
            : nil
    }

    // MARK: - Panel lifecycle

    @objc private func togglePanel() {
        logInfo("StatusItem: togglePanel (visible=\(panel?.isVisible ?? false))")
        if let panel, panel.isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    func showPanel() {
        guard let meetingStore, let hotkeyManager else {
            logError("StatusItem: showPanel aborted — not configured")
            return
        }

        let panel = self.panel ?? makePanel(meetingStore: meetingStore, hotkeyManager: hotkeyManager)
        self.panel = panel

        sizeAndPosition(panel)
        panel.makeKeyAndOrderFront(nil)
        statusItem?.button?.highlight(true)
        installDismissMonitors()
        logInfo("StatusItem: showPanel frame=\(NSStringFromRect(panel.frame)) visible=\(panel.isVisible) key=\(panel.isKeyWindow) canKey=\(panel.canBecomeKey)")
    }

    func hidePanel() {
        removeDismissMonitors()
        panel?.orderOut(nil)
        statusItem?.button?.highlight(false)
    }

    private func makePanel(meetingStore: MeetingStore, hotkeyManager: HotkeyManager) -> NSPanel {
        let root = PanelRoot {
            MenuBarView()
                .environmentObject(meetingStore)
                .environmentObject(hotkeyManager)
        }
        let host = NSHostingView(rootView: AnyView(root))

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 200),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .moveToActiveSpace]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovable = false
        panel.contentView = host
        return panel
    }

    /// Re-measures the hosting view (content height varies with calendar contents) and positions the
    /// panel centered under the status item button, just below the menu bar.
    private func sizeAndPosition(_ panel: NSPanel) {
        guard let host = panel.contentView else { return }
        var size = host.fittingSize
        if size.width <= 0 { size.width = 360 }
        if size.height <= 0 { size.height = 200 }
        panel.setContentSize(size)

        guard let button = statusItem?.button, let buttonWindow = button.window else { return }
        let buttonRect = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let screen = buttonWindow.screen ?? NSScreen.main
        let visible = screen?.visibleFrame ?? buttonRect

        var x = buttonRect.midX - size.width / 2
        // Keep the panel on-screen horizontally.
        x = max(visible.minX + 8, min(x, visible.maxX - size.width - 8))
        let y = buttonRect.minY - size.height - topGap

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: - Dismissal

    private func installDismissMonitors() {
        removeDismissMonitors()
        // Clicks in other applications.
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.hidePanel() }
        }
        // Clicks in our own other windows (e.g. settings / meeting window) — but not inside the panel.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let self, event.window != self.panel {
                self.hidePanel()
            }
            return event
        }
    }

    private func removeDismissMonitors() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }
}

/// Wraps the popup content in a rounded material background. The panel itself is clear/borderless,
/// so the content must draw its own chrome.
private struct PanelRoot<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .background(VisualEffectBackground(material: .menu, blendingMode: .behindWindow))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
            .fixedSize()
    }
}
