import AppKit
import SwiftUI

/// The transcript as one read-only text view, so a selection can run across turns, and ⌘A, ⌘C
/// and ⌘F behave as they do in any Mac document. Each paragraph is laid out the way the export
/// writes it ("Name · 00:12", then the text, a blank line between turns), so a copied selection
/// pastes in the same shape as Copy Transcript.
struct TranscriptTextView: NSViewRepresentable {
    let blocks: [TranscriptFormatter.Block]
    let selfName: String?
    let othersName: String?
    /// True while the reader is at the end; new turns are followed only then.
    @Binding var isPinnedToBottom: Bool
    /// Bump to scroll to the end and resume following.
    let jumpRequest: Int

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        // TextKit 1: the scroll-to-end below needs real line heights, not TextKit 2's estimates.
        let textView = ReflowingTextView(usingTextLayoutManager: false)
        textView.isEditable = false
        textView.isSelectable = true
        // Copies and drags plain text. Rich text would carry this view's appearance colours, so a
        // selection from a dark window pasted into a light document would come out white on white.
        // The styling set on the storage below is kept; this only governs the pasteboard.
        textView.isRichText = false
        textView.drawsBackground = false
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.textContainerInset = NSSize(
            width: Theme.Spacing.rowHorizontal, height: Theme.Spacing.rowHorizontal)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        textView.setAccessibilityLabel("Transcript")

        scrollView.documentView = textView
        context.coordinator.attach(to: scrollView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        guard let storage = (scrollView.documentView as? NSTextView)?.textStorage else { return }
        coordinator.render(blocks, names: Names(selfName: selfName, othersName: othersName), into: storage)
        if jumpRequest != coordinator.lastJumpRequest {
            coordinator.lastJumpRequest = jumpRequest
            coordinator.scrollToEnd()
        }
    }

    struct Names: Equatable {
        let selfName: String?
        let othersName: String?
    }

    @MainActor
    final class Coordinator: NSObject {
        var parent: TranscriptTextView
        var lastJumpRequest = 0

        private weak var scrollView: NSScrollView?
        private var isPinned = true
        private var lastBounds = NSRect.zero
        private var rendered: [TranscriptFormatter.Block] = []
        private var renderedNames: Names?
        /// UTF-16 offset where each rendered block starts, including its leading blank line.
        private var blockStarts: [Int] = []

        init(parent: TranscriptTextView) {
            self.parent = parent
            lastJumpRequest = parent.jumpRequest
        }

        func attach(to scrollView: NSScrollView) {
            self.scrollView = scrollView
            let clip = scrollView.contentView
            clip.postsBoundsChangedNotifications = true
            clip.postsFrameChangedNotifications = true
            // Scrolls move the bounds; a window resize changes the frame and posts only that.
            NotificationCenter.default.addObserver(
                self, selector: #selector(visibleRectChanged), name: NSView.boundsDidChangeNotification,
                object: clip)
            NotificationCenter.default.addObserver(
                self, selector: #selector(visibleRectChanged), name: NSView.frameDidChangeNotification,
                object: clip)
            (scrollView.documentView as? ReflowingTextView)?.didResize = { [weak self] in
                guard let self, self.isPinned else { return }
                self.scrollToEnd()
            }
        }

        /// Rewrites only from the first block that changed. A streaming turn revises the tail
        /// several times a second; rewriting it all would drop the reader's selection each time.
        func render(_ blocks: [TranscriptFormatter.Block], names: Names, into storage: NSTextStorage) {
            var first = 0
            if names == renderedNames {
                while first < min(blocks.count, rendered.count), blocks[first] == rendered[first] {
                    first += 1
                }
                if first == blocks.count, first == rendered.count { return }
            }

            let start = first < blockStarts.count ? blockStarts[first] : storage.length
            var starts = Array(blockStarts.prefix(first))
            let tail = NSMutableAttributedString()
            for index in first..<blocks.count {
                starts.append(start + tail.length)
                tail.append(Self.paragraph(blocks[index], isFirst: index == 0, names: names))
            }

            storage.beginEditing()
            storage.replaceCharacters(
                in: NSRange(location: start, length: storage.length - start), with: tail)
            storage.endEditing()
            rendered = blocks
            renderedNames = names
            blockStarts = starts
        }

        func scrollToEnd() {
            guard let scrollView, let document = scrollView.documentView else { return }
            let clip = scrollView.contentView
            var end = clip.bounds
            end.origin.y = document.frame.maxY
            clip.scroll(to: clip.constrainBoundsRect(end).origin)
            scrollView.reflectScrolledClipView(clip)
        }

        /// A scroll that moves the view, whether the reader's, a find match or the keyboard,
        /// decides following. A resize moves the origin too, but never stops following: it keeps
        /// the end in view, and only resumes following if the end came into view.
        @objc private func visibleRectChanged() {
            guard let scrollView, let document = scrollView.documentView as? ReflowingTextView,
                !document.isResizing
            else { return }
            let bounds = scrollView.contentView.bounds
            let resized = bounds.size != lastBounds.size
            let moved = bounds.origin != lastBounds.origin
            lastBounds = bounds
            let atEnd = bounds.maxY >= document.frame.height - 24
            if resized {
                if isPinned { scrollToEnd() } else if atEnd { setPinned(true) }
            } else if moved {
                setPinned(atEnd)
            }
        }

        private func setPinned(_ pinned: Bool) {
            guard pinned != isPinned else { return }
            isPinned = pinned
            // Posted from inside AppKit layout, which can run during a SwiftUI update.
            let binding = parent.$isPinnedToBottom
            DispatchQueue.main.async { binding.wrappedValue = pinned }
        }

        private static func paragraph(
            _ block: TranscriptFormatter.Block,
            isFirst: Bool,
            names: Names
        ) -> NSAttributedString {
            let body = body(isPartial: block.isPartial)
            let result = NSMutableAttributedString()
            if !isFirst { result.append(NSAttributedString(string: "\n\n", attributes: body)) }
            let name = TranscriptFormatter.displayName(
                for: block.speaker,
                selfName: names.selfName,
                othersName: names.othersName,
                diarizedSpeaker: block.diarizedSpeaker
            )
            result.append(NSAttributedString(string: name, attributes: speaker))
            result.append(
                NSAttributedString(
                    string: " · \(TranscriptFormatter.timestampString(block.startedAt))\n",
                    attributes: timestamp))
            result.append(NSAttributedString(string: block.text, attributes: body))
            return result
        }

        private static let heading: NSParagraphStyle = {
            let style = NSMutableParagraphStyle()
            style.paragraphSpacing = Theme.Spacing.xs
            return style
        }()

        private static let speaker: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor(Color.textPrimary),
            .paragraphStyle: heading
        ]

        private static let timestamp: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor(Color.textSecondary),
            .paragraphStyle: heading
        ]

        private static func body(isPartial: Bool) -> [NSAttributedString.Key: Any] {
            let style = NSMutableParagraphStyle()
            style.lineSpacing = 2
            return [
                .font: NSFont.systemFont(ofSize: 13),
                // A turn still being revised is dimmed, so a rewrite doesn't read as text being deleted.
                .foregroundColor: NSColor(isPartial ? Color.textSecondary : Color.textPrimary),
                .paragraphStyle: style
            ]
        }
    }
}

/// Says when its frame has finished changing. Reflowing to a new width, NSTextView scrolls its old
/// visible text back into view from inside `setFrameSize`; that scroll is layout, not the reader
/// moving, so it mustn't stop following, and following has to be restored once it's done.
private final class ReflowingTextView: NSTextView {
    private(set) var isResizing = false
    var didResize: (() -> Void)?

    override func setFrameSize(_ newSize: NSSize) {
        let wasResizing = isResizing
        isResizing = true
        super.setFrameSize(newSize)
        isResizing = wasResizing
        if !wasResizing { didResize?() }
    }
}
