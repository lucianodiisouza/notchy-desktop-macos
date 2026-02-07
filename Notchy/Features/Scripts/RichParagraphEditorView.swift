import AppKit
import SwiftUI

/// Notificação para a barra de formatação aplicar wrap na seleção do first responder.
/// userInfo: "prefix" (String), "suffix" (String).
extension Notification.Name {
    static let scriptEditorApplyFormatWrap = Notification.Name("scriptEditorApplyFormatWrap")
}

/// NSTextView que mostra markdown como atribuído (live preview) e converte de/para markdown.
final class RichParagraphNSTextView: NSTextView {
    var onMarkdownDidChange: ((String) -> Void)?
    var baseFont: NSFont = .systemFont(ofSize: NSFont.systemFontSize)
    var textColorValue: NSColor = .labelColor

    override func didChangeText() {
        super.didChangeText()
        let att = attributedString()
        let md = InlineMarkdown.markdown(from: att, baseFont: baseFont)
        onMarkdownDidChange?(md)
    }

    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        if ok { startObservingFormatWrap() }
        return ok
    }

    override func resignFirstResponder() -> Bool {
        stopObservingFormatWrap()
        return super.resignFirstResponder()
    }

    private var formatWrapObserver: NSObjectProtocol?

    private func startObservingFormatWrap() {
        stopObservingFormatWrap()
        formatWrapObserver = NotificationCenter.default.addObserver(
            forName: .scriptEditorApplyFormatWrap,
            object: nil,
            queue: .main
        ) { [weak self] notif in
            guard let self = self, self.window?.firstResponder === self else { return }
            guard let prefix = (notif.userInfo?["prefix"] as? String),
                  let suffix = (notif.userInfo?["suffix"] as? String) else { return }
            self.wrapSelection(prefix: prefix, suffix: suffix)
        }
    }

    private func stopObservingFormatWrap() {
        if let o = formatWrapObserver {
            NotificationCenter.default.removeObserver(o)
            formatWrapObserver = nil
        }
    }

    private func wrapSelection(prefix: String, suffix: String) {
        let r = selectedRange
        let str = string as NSString
        let selected = r.length > 0 ? str.substring(with: r) : ""
        let replacement = prefix + selected + suffix
        if shouldChangeText(in: r, replacementString: replacement) {
            replaceCharacters(in: r, with: replacement)
            didChangeText()
            setSelectedRange(NSRange(location: r.location + prefix.count, length: selected.count))
        }
    }

    deinit {
        stopObservingFormatWrap()
    }
}

// MARK: - SwiftUI wrapper

struct RichParagraphEditorView: NSViewRepresentable {
    @Binding var markdown: String
    var fontSize: Double
    var fontName: String?

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = false
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder

        let textView = RichParagraphNSTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = true
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.minSize = NSSize(width: 0, height: 24)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.usesFindBar = false

        scroll.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.scrollView = scroll
        return scroll
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView as? RichParagraphNSTextView else { return }
        let font = fontName.flatMap { NSFont(name: $0, size: CGFloat(fontSize)) } ?? .systemFont(ofSize: CGFloat(fontSize))
        let color = NSColor.labelColor
        textView.baseFont = font
        textView.textColorValue = color
        let desired = InlineMarkdown.attributedString(from: markdown, font: font, color: color)
        if context.coordinator.lastBoundMarkdown != markdown {
            textView.textStorage?.setAttributedString(desired)
            textView.font = font
            textView.textColor = color
            context.coordinator.lastBoundMarkdown = markdown
        }
        textView.onMarkdownDidChange = { newMd in
            if newMd != context.coordinator.lastBoundMarkdown {
                context.coordinator.lastBoundMarkdown = newMd
                self.markdown = newMd
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject {
        var textView: NSTextView?
        var scrollView: NSScrollView?
        var lastBoundMarkdown: String = ""
    }
}
