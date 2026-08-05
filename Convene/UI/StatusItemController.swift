import AppKit
import Combine
import SwiftUI

/// Owns the menu bar status item and an `NSPopover` that hosts `MenuBarView`.
///
/// Replaces SwiftUI's `MenuBarExtra(.window)`, whose panel rendered flush against the menu bar and
/// clipped its own rounded top corners. `NSPopover` anchors below the status item with native
/// chrome (rounded corners, no clipping), handles first-mouse so a single click actuates controls
/// even when the app is in the background, and dismisses itself on outside clicks. This mirrors how
/// polished menu bar apps present their popovers.
@MainActor
final class StatusItemController {
    static let shared = StatusItemController()

    private weak var meetingStore: MeetingStore?
    private weak var hotkeyManager: HotkeyManager?

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var tintCancellable: AnyCancellable?
    private var calendarCancellables = Set<AnyCancellable>()
    private var countdownTimer: Timer?
    /// The app's waveform icon, shown when no event is imminent.
    private var iconImage: NSImage?
    /// Mirror of capture state, set from the publisher so the menu-bar render is never one step behind.
    private var isRecording = false

    private init() {}

    func configure(meetingStore: MeetingStore, hotkeyManager: HotkeyManager) {
        self.meetingStore = meetingStore
        self.hotkeyManager = hotkeyManager
    }

    func installStatusItem() {
        guard statusItem == nil, let meetingStore else { return }

        // Variable length so the item grows to fit the event-name pill; a square item would clip it.
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            // A concrete size forces the vector asset to render as a proper template image, which is
            // what lets the status bar invert it for light/dark menu bars. Without an explicit size
            // the SVG's preserved vector representation renders with its literal fill (black), so it
            // disappears on a dark menu bar.
            let image = NSImage(named: "MenuBarIcon")
            image?.isTemplate = true
            image?.size = NSSize(width: 18, height: 18)
            iconImage = image
            button.image = image
            button.imageScaling = .scaleProportionallyDown
            button.imagePosition = .imageOnly
            button.target = self
            button.action = #selector(togglePopover)
            button.setAccessibilityLabel("Convene")
        }
        statusItem = item

        // Re-render the menu bar item (icon/text) whenever recording starts/stops so the red
        // recording colour is baked into the image — contentTintColor is unreliable for status items.
        tintCancellable = meetingStore.captureCoordinator.$isCapturing
            .receive(on: RunLoop.main)
            .sink { [weak self] capturing in
                self?.isRecording = capturing
                self?.updateMenuBarTitle()
            }

        // Menu bar pill: show the upcoming event's name + countdown starting `leadTimeMinutes` before.
        meetingStore.calendarService.$events
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateMenuBarTitle() }
            .store(in: &calendarCancellables)
        CalendarSettings.shared.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                // objectWillChange fires before the value updates; refresh on the next runloop tick.
                DispatchQueue.main.async { self?.updateMenuBarTitle() }
            }
            .store(in: &calendarCancellables)
        // Tick the countdown every 30s.
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateMenuBarTitle() }
        }
        RunLoop.main.add(timer, forMode: .common)
        countdownTimer = timer
        updateMenuBarTitle()
    }

    // MARK: - Menu bar pill

    private func updateMenuBarTitle() {
        guard let button = statusItem?.button, let meetingStore else { return }
        button.contentTintColor = nil  // colour is baked into the image below
        let recording = isRecording
        let lead = CalendarSettings.shared.leadTimeMinutes

        if let event = meetingStore.calendarService.menuBarEvent(leadMinutes: lead) {
            // Imminent event: show just the name + countdown (no app icon), Raycast-style.
            let text = "\(Self.truncate(event.title, max: 24)) · \(Self.countdownText(for: event))"
            // Red (literal) while recording; otherwise a template that adapts to the menu bar.
            button.image = Self.textImage(text, color: recording ? .systemRed : .black, template: !recording)
            button.toolTip = event.title
        } else {
            // No imminent event: show the icon (persistent click target). Red while recording.
            button.image = recording ? Self.tinted(iconImage, color: .systemRed) : iconImage
            button.toolTip = nil
        }
        reanchorPopoverIfShown()
    }

    /// Re-anchor an open popover after the status item's width changes.
    ///
    /// The item is `variableLength`, so swapping the event pill for the icon — which is what
    /// dismissing the upcoming event from inside the popover does — resizes it and shifts every
    /// item to its left. `NSPopover` positions itself once at `show(relativeTo:)` and does not
    /// follow, leaving the panel stranded beside the item with its arrow detached. Re-assigning
    /// `positioningRect` makes it recompute against the button's new frame.
    private func reanchorPopoverIfShown() {
        guard let popover, popover.isShown, let button = statusItem?.button else { return }
        // The status item lays out its new width on the next pass; re-anchoring before that would
        // just reposition against the stale frame.
        DispatchQueue.main.async {
            guard popover.isShown else { return }
            popover.positioningRect = button.bounds
        }
    }

    /// Render menu-bar text into an image. `template` makes it adapt to the menu bar appearance
    /// (white on dark); a non-template image renders in `color` literally (used for recording-red).
    private static func textImage(_ text: String, color: NSColor, template: Bool) -> NSImage {
        let font = NSFont.menuBarFont(ofSize: 0)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let string = text as NSString
        let size = string.size(withAttributes: attrs)
        let image = NSImage(size: NSSize(width: ceil(size.width), height: ceil(size.height)))
        image.lockFocus()
        string.draw(at: .zero, withAttributes: attrs)
        image.unlockFocus()
        image.isTemplate = template
        return image
    }

    /// A copy of `icon` filled with `color` (non-template) — used to colour the icon while recording.
    private static func tinted(_ icon: NSImage?, color: NSColor) -> NSImage? {
        guard let icon else { return nil }
        let image = NSImage(size: icon.size)
        image.lockFocus()
        icon.draw(in: NSRect(origin: .zero, size: icon.size))
        color.set()
        NSRect(origin: .zero, size: icon.size).fill(using: .sourceAtop)
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private static func truncate(_ string: String, max: Int) -> String {
        string.count <= max ? string : String(string.prefix(max - 1)) + "…"
    }

    private static func countdownText(for event: MeetingEvent) -> String {
        if event.isInProgress {
            let elapsedMinutes = max(0, Int(Date().timeIntervalSince(event.startDate) / 60))
            if elapsedMinutes >= 60 {
                let h = elapsedMinutes / 60
                let m = elapsedMinutes % 60
                return m == 0 ? "\(h)h ago" : "\(h)h \(m)m ago"
            }
            return elapsedMinutes == 0 ? "Now" : "\(elapsedMinutes)m ago"
        }
        let seconds = event.startDate.timeIntervalSinceNow
        let minutes = max(0, Int(ceil(seconds / 60)))
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m == 0 ? "in \(h)h" : "in \(h)h \(m)m"
        }
        return "in \(minutes)m"
    }

    // MARK: - Popover lifecycle

    @objc private func togglePopover() {
        if let popover, popover.isShown {
            hidePanel()
        } else {
            showPopover()
        }
    }

    func showPopover() {
        guard let meetingStore, let hotkeyManager, let button = statusItem?.button else { return }

        let popover = self.popover ?? makePopover(meetingStore: meetingStore, hotkeyManager: hotkeyManager)
        self.popover = popover

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        // Focus, in the two steps it actually takes.
        //
        // Convene is an accessory app (`LSUIElement`), so before `show` there is no window for
        // activation to bring forward and the request is dropped — activation has to come after.
        // Activation alone is still not enough: clicking a status item does not confer key status
        // on the popover's window, and a non-key window renders its material in the dimmed inactive
        // state and takes no keyboard focus, even while frontmost. `makeKey` is what closes that
        // gap. It also keeps the hosting view in an active context, so SwiftUI doesn't throttle
        // updates and the Record button flips to Stop live rather than only on reopen.
        NSApp.activate()
        popover.contentViewController?.view.window?.makeKey()

        brightenBackdrop(of: popover)
        // AppKit builds the chrome as part of the show animation, so a single pass at show time can
        // land before the effect view exists. Re-apply once the animation has settled.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self, let popover = self.popover, popover.isShown else { return }
            self.brightenBackdrop(of: popover)
        }
    }

    /// Render the popover's material at full brightness instead of the dimmed inactive state.
    ///
    /// Deliberately independent of the activation above. `NSVisualEffectView` defaults to
    /// `state == .followsWindowActiveState`, which is the right default for a document window — a
    /// background window *should* recede. A menu bar panel is the opposite: it is only ever on
    /// screen because the user just clicked it, so it should always read as focused. Making the
    /// window key earns that honestly; pinning `.active` makes it unconditional, so the panel does
    /// not dim mid-animation or if activation loses a race with another app.
    ///
    /// The walk is recursive and starts at the window's frame view because the effect view's depth
    /// in the popover's private hierarchy is not contractual.
    private func brightenBackdrop(of popover: NSPopover) {
        guard let window = popover.contentViewController?.view.window else { return }
        func brighten(_ view: NSView) {
            if let effectView = view as? NSVisualEffectView { effectView.state = .active }
            view.subviews.forEach(brighten)
        }
        if let root = window.contentView?.superview ?? window.contentView { brighten(root) }
    }

    /// Named `hidePanel` for the call sites in `MenuBarView` that dismiss the popup before opening
    /// another window.
    func hidePanel() {
        popover?.performClose(nil)
    }

    private func makePopover(meetingStore: MeetingStore, hotkeyManager: HotkeyManager) -> NSPopover {
        let host = NSHostingController(
            rootView: AnyView(
                MenuBarView()
                    .environmentObject(meetingStore)
                    .environmentObject(hotkeyManager)
            )
        )
        // Let the popover size itself to the SwiftUI content (width is fixed at 360 by MenuBarView;
        // height varies with the calendar).
        host.sizingOptions = [.preferredContentSize]

        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = host
        return popover
    }
}
