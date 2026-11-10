import AppKit
import Combine
import SwiftUI

/// Notification when user pastes in the teleprompter. userInfo["pastedText"] = pasted string.
extension Notification.Name {
    static let teleprompterDidPaste = Notification.Name("teleprompterDidPaste")
}

/// Pastes plain text only, keeping line breaks. Pasting into an empty prompter posts `.teleprompterDidPaste` so the app
/// starts a script from it; pasting into existing text is an ordinary edit.
/// Also turns off the automatic scroll-to-selection, which made the text jump between paragraphs while the voice drives
/// the scroll (only ScrollController moves the text).
private final class PlainTextPasteTextView: NSTextView {
    override func paste(_ sender: Any?) {
        guard let pasted = NSPasteboard.general.string(forType: .string), !pasted.isEmpty else {
            super.paste(sender)
            return
        }
        if string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            NotificationCenter.default.post(name: .teleprompterDidPaste, object: self, userInfo: ["pastedText": pasted])
        } else {
            // insertText goes through the normal editing path, so undo works and the change is saved.
            insertText(pasted, replacementRange: selectedRange())
        }
    }

    override func scrollRangeToVisible(_ range: NSRange) {
        // Keep the insertion point visible while typing, but never scroll for a selection.
        if range.length == 0 {
            super.scrollRangeToVisible(range)
        }
    }
}

/// 0 = left, 1 = center, 2 = right, 3 = justify
struct TeleprompterTextView: NSViewRepresentable {
    @Binding var text: String
    let scrollController: ScrollController
    let speechFollower: SpeechFollower
    var fontSize: Double
    var textColor: Color
    var textOpacity: Double = 1
    var alignmentMode: Int = 0
    /// Fade the words already read and mark the current one ("follow my words").
    var showsReadingPosition: Bool = false

    private var effectiveTextColor: NSColor {
        NSColor(textColor).withAlphaComponent(CGFloat(min(1, max(0, textOpacity))))
    }

    private var nsAlignment: NSTextAlignment {
        switch alignmentMode {
        case 1: return .center
        case 2: return .right
        case 3: return .justified
        default: return .left
        }
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.scrollerStyle = .overlay
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.contentView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

        let textView = PlainTextPasteTextView(frame: NSRect(x: 0, y: 0, width: 300, height: 100))
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.font = .systemFont(ofSize: fontSize)
        textView.textColor = effectiveTextColor
        textView.string = text
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.layoutManager?.allowsNonContiguousLayout = false  // contiguous layout: no re-layout jumps while scrolling

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = nsAlignment
        textView.defaultParagraphStyle = paragraphStyle
        textView.typingAttributes[.paragraphStyle] = paragraphStyle

        scrollView.documentView = textView
        textView.delegate = context.coordinator
        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView
        context.coordinator.observe(scrollView: scrollView, scrollController: scrollController, follower: speechFollower)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        let coordinator = context.coordinator
        coordinator.parent = self
        if !coordinator.ignoreNextSyncFromBinding {
            if textView.string != text {
                // Never blank the view with an empty binding that has not caught up yet (e.g. right after a paste);
                // push the view's text back instead.
                if text.isEmpty && !textView.string.isEmpty {
                    coordinator.parent.text = textView.string
                } else {
                    textView.string = text
                }
            }
        } else {
            coordinator.ignoreNextSyncFromBinding = false
        }
        // Restyling the whole text lays it out again, so only do it when the look or the text changed; the view
        // re-renders on every word heard while following.
        let style = Coordinator.Style(fontSize: fontSize, color: effectiveTextColor, alignment: nsAlignment, text: textView.string)
        if style != coordinator.appliedStyle {
            coordinator.appliedStyle = style
            textView.font = .systemFont(ofSize: fontSize)
            textView.textColor = effectiveTextColor
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = nsAlignment
            textView.defaultParagraphStyle = paragraphStyle
            textView.typingAttributes[.paragraphStyle] = paragraphStyle
            let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
            if fullRange.length > 0 {
                textView.textStorage?.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)
            }
            coordinator.invalidateReadingPosition()
            textView.needsDisplay = true
        }
        coordinator.showReadingPosition(showsReadingPosition ? speechFollower.currentWordRange : nil)
        // The size or text may have changed: put the text back where the controller has it.
        coordinator.apply(offset: scrollController.scrollOffset)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: TeleprompterTextView
        weak var textView: NSTextView?
        weak var scrollView: NSScrollView?
        /// When true, the next updateNSView leaves the text view's string alone (it is the source of the change).
        var ignoreNextSyncFromBinding = false
        private var scrollBoundsObserver: NSObjectProtocol?
        private var cancellables = Set<AnyCancellable>()
        private weak var scrollController: ScrollController?
        private weak var follower: SpeechFollower?
        /// Set while we move the clip view ourselves, so the bounds observer does not echo it back.
        private var isApplyingOffset = false
        /// Set while a hand scroll is passed on to the controller, so it is not applied back to the view.
        private var isReportingUserScroll = false
        private var markedRange: NSRange?

        struct Style: Equatable {
            let fontSize: Double
            let color: NSColor
            let alignment: NSTextAlignment
            let text: String
        }
        var appliedStyle: Style?

        /// The text or its look changed: draw the reading marks again on the next update.
        func invalidateReadingPosition() {
            markedRange = nil
        }

        init(_ parent: TeleprompterTextView) {
            self.parent = parent
        }

        deinit {
            if let observer = scrollBoundsObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        func observe(scrollView: NSScrollView, scrollController: ScrollController, follower: SpeechFollower) {
            self.scrollController = scrollController
            self.follower = follower

            // The reader scrolled by hand (trackpad, scroll bar): that becomes the new offset.
            scrollView.contentView.postsBoundsChangedNotifications = true
            scrollBoundsObserver = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: scrollView.contentView,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, !self.isApplyingOffset, let scrollView = self.scrollView else { return }
                    self.scrollController?.maxOffset = self.maxOffset
                    // Only the reader's own scrolling counts. The clip view also moves while the window opens,
                    // collapses or resizes, to places like -208 that are not a reading position.
                    let event = NSApp.currentEvent?.type
                    guard event == .scrollWheel || event == .leftMouseDragged else {
                        // Layout moved it (e.g. to -208 while the view got its size): put it back where the controller
                        // says, once the layout pass is over.
                        DispatchQueue.main.async { [weak self] in
                            guard let self, let controller = self.scrollController else { return }
                            self.apply(offset: controller.scrollOffset, force: true)
                        }
                        return
                    }
                    // The reader took over: stop easing back to the last heard word until a new one comes in.
                    self.scrollController?.followTarget = nil
                    self.isReportingUserScroll = true
                    self.scrollController?.scrollOffset = min(max(0, scrollView.contentView.bounds.origin.y), self.maxOffset)
                    self.isReportingUserScroll = false
                }
            }

            // The controller moved the text: scroll the view directly, without a SwiftUI update per frame.
            scrollController.$offsetValue
                .dropFirst()
                .sink { [weak self] offset in
                    MainActor.assumeIsolated { self?.apply(offset: offset) }
                }
                .store(in: &cancellables)

            // A new word was heard: aim the scroll at its line.
            follower.$currentWordRange
                .receive(on: RunLoop.main)
                .sink { [weak self] range in self?.follow(range) }
                .store(in: &cancellables)
        }

        /// How far the text can scroll: its height minus the visible part.
        private var maxOffset: CGFloat {
            guard let scrollView else { return 0 }
            return max(0, (scrollView.documentView?.frame.height ?? 0) - scrollView.contentView.bounds.height)
        }

        func apply(offset: CGFloat, force: Bool = false) {
            guard let scrollView else { return }
            let clip = scrollView.contentView
            let maxY = maxOffset
            scrollController?.maxOffset = maxY
            // Laid out while the scroll view was still zero-sized, the text view can end up above the visible area
            // (origin -702 with a 702 pt script). Its top belongs at the top of the document.
            if let textView, textView.frame.origin != .zero {
                textView.setFrameOrigin(.zero)
            }
            let y = min(max(0, offset), maxY)
            // Out of range (end of the text, or the text got shorter): pull the offset back so it never runs on
            // invisibly and then jumps.
            if y != offset {
                // Not during the view update that called us: publish on the next turn.
                DispatchQueue.main.async { [weak self] in self?.scrollController?.scrollOffset = y }
                return
            }
            guard !isReportingUserScroll, force || abs(clip.bounds.origin.y - y) > 0.25 else { return }
            isApplyingOffset = true
            clip.scroll(to: NSPoint(x: clip.bounds.origin.x, y: y))
            scrollView.reflectScrolledClipView(clip)
            isApplyingOffset = false
        }

        /// Keeps the line with `range` about a third of the way down the visible area.
        private func follow(_ range: NSRange?) {
            guard let range, let rect = rect(for: range), let scrollView else {
                scrollController?.followTarget = range == nil ? 0 : scrollController?.followTarget
                if parent.showsReadingPosition { showReadingPosition(range) }
                return
            }
            let visible = scrollView.contentView.bounds.height
            scrollController?.followTarget = max(0, rect.minY - visible * 0.3)
            if parent.showsReadingPosition { showReadingPosition(range) }
        }

        private func rect(for range: NSRange) -> NSRect? {
            guard let textView, let layoutManager = textView.layoutManager, let container = textView.textContainer,
                  NSMaxRange(range) <= (textView.string as NSString).length else { return nil }
            let glyphs = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            var rect = layoutManager.boundingRect(forGlyphRange: glyphs, in: container)
            rect.origin.y += textView.textContainerOrigin.y
            return rect
        }

        /// Dims the words already read and underlines the current one. Temporary attributes only change drawing, never
        /// the script itself.
        func showReadingPosition(_ range: NSRange?) {
            guard range != markedRange, let textView, let layoutManager = textView.layoutManager else { return }
            markedRange = range
            let length = (textView.string as NSString).length
            layoutManager.removeTemporaryAttribute(.foregroundColor, forCharacterRange: NSRange(location: 0, length: length))
            layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: NSRange(location: 0, length: length))
            guard let range, NSMaxRange(range) <= length else { return }
            let color = textView.textColor ?? .white
            layoutManager.addTemporaryAttribute(
                .foregroundColor, value: color.withAlphaComponent(color.alphaComponent * 0.4),
                forCharacterRange: NSRange(location: 0, length: range.location))
            layoutManager.addTemporaryAttribute(
                .backgroundColor, value: NSColor.systemYellow.withAlphaComponent(0.35), forCharacterRange: range)
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = textView else { return }
            ignoreNextSyncFromBinding = true
            parent.text = textView.string
        }

        /// Clicking a word while following speech continues from that word.
        func textViewDidChangeSelection(_ notification: Notification) {
            guard parent.showsReadingPosition, let textView, NSApp.currentEvent?.type == .leftMouseUp
                    || NSApp.currentEvent?.type == .leftMouseDown else { return }
            let selection = textView.selectedRange()
            guard selection.length == 0 else { return }
            follower?.jump(toCharacter: selection.location)
        }
    }
}
