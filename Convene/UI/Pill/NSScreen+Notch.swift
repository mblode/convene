import AppKit

/// Notch geometry helpers, modelled on the canonical approach used by well-maintained
/// open-source notch libraries (e.g. DynamicNotchKit, boring.notch): detect via the
/// auxiliary menu-bar areas flanking the camera housing, and derive the notch rect from the
/// safe-area top inset. More reliable than `safeAreaInsets.top` alone, which can be non-zero
/// on some external displays.
extension NSScreen {
    /// True on built-in displays with a camera-housing notch (2021+ MacBook Pro / Air).
    var hasNotch: Bool {
        auxiliaryTopLeftArea != nil && auxiliaryTopRightArea != nil && safeAreaInsets.top > 0
    }

    /// Menu-bar height on this screen — also the notch height on notched displays.
    var menubarHeight: CGFloat {
        frame.maxY - visibleFrame.maxY
    }

    /// The notch's rect in screen (bottom-left origin) coordinates, or nil on non-notched
    /// screens. Width is the gap between the two auxiliary menu-bar areas; height is the
    /// safe-area top inset.
    var notchFrame: NSRect? {
        guard hasNotch,
              let leftWidth = auxiliaryTopLeftArea?.width,
              let rightWidth = auxiliaryTopRightArea?.width else { return nil }
        let width = frame.width - leftWidth - rightWidth
        guard width > 0 else { return nil }
        let height = safeAreaInsets.top
        return NSRect(
            x: frame.midX - width / 2,
            y: frame.maxY - height,
            width: width,
            height: height
        )
    }
}
