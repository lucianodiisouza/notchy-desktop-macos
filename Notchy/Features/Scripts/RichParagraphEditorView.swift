import AppKit
import SwiftUI

/// Format to apply to the current selection (rich text, no markdown).
enum ScriptEditorFormat: String {
    case bold
    case italic
    case underline
    case fontSize
}

/// Notificação para a barra aplicar formatação real na seleção.
/// userInfo: "format" (ScriptEditorFormat rawValue), "pointSize" (Int, só para .fontSize).
extension Notification.Name {
    static let scriptEditorApplyFormat = Notification.Name("scriptEditorApplyFormat")
}

/// NSTextView com rich text em tempo real. Persistência em RTF + plain body.
final class RichParagraphNSTextView: NSTextView {
    var onContentDidChange: ((String, Data?) -> Void)?
    var baseFont: NSFont = .systemFont(ofSize: NSFont.systemFontSize)
    var textColorValue: NSColor = .labelColor
    override func didChangeText() {
        super.didChangeText()
        reportContent()
    }

    private func reportContent() {
        let att = attributedString()
        let plain = att.string
        let rtfData: Data? = {
            guard att.length > 0 else { return nil }
            let range = NSRange(location: 0, length: att.length)
            return try? att.data(from: range, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        }()
        onContentDidChange?(plain, rtfData)
    }

    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        if ok { startObservingApplyFormat() }
        return ok
    }

    override func resignFirstResponder() -> Bool {
        stopObservingApplyFormat()
        return super.resignFirstResponder()
    }

    private var formatObserver: NSObjectProtocol?

    private func startObservingApplyFormat() {
        stopObservingApplyFormat()
        formatObserver = NotificationCenter.default.addObserver(
            forName: .scriptEditorApplyFormat,
            object: nil,
            queue: .main
        ) { [weak self] notif in
            guard let self = self, self.window?.firstResponder === self else { return }
            guard let raw = notif.userInfo?["format"] as? String,
                  let format = ScriptEditorFormat(rawValue: raw) else { return }
            let pointSize = notif.userInfo?["pointSize"] as? Int
            self.applyFormat(format, pointSize: pointSize)
        }
    }

    private func stopObservingApplyFormat() {
        if let o = formatObserver {
            NotificationCenter.default.removeObserver(o)
            formatObserver = nil
        }
    }

    private func applyFormat(_ format: ScriptEditorFormat, pointSize: Int?) {
        guard let storage = textStorage else { return }
        let range = selectedRange()
        // Nothing selected: the format applies to what is typed next, never to the whole document.
        guard range.length > 0 else {
            applyToTypingAttributes(format, pointSize: pointSize)
            return
        }
        if case .fontSize = format, pointSize.map({ $0 < 6 || $0 > 200 }) ?? true { return }
        // Going through shouldChangeText/didChangeText makes the change undoable and saves it like any edit.
        guard shouldChangeText(in: range, replacementString: nil) else { return }
        storage.beginEditing()
        switch format {
        case .bold, .italic:
            let mask: NSFontTraitMask = format == .bold ? .boldFontMask : .italicFontMask
            let trait: NSFontDescriptor.SymbolicTraits = format == .bold ? .bold : .italic
            storage.enumerateAttribute(.font, in: range) { value, sub, _ in
                let font = (value as? NSFont) ?? baseFont
                let newFont = font.fontDescriptor.symbolicTraits.contains(trait)
                    ? NSFontManager.shared.convert(font, toNotHaveTrait: mask)
                    : NSFontManager.shared.convert(font, toHaveTrait: mask)
                storage.addAttribute(.font, value: newFont, range: sub)
            }
        case .underline:
            var hasUnderline = false
            storage.enumerateAttribute(.underlineStyle, in: range) { value, _, stop in
                if (value as? Int) == NSUnderlineStyle.single.rawValue { hasUnderline = true; stop.pointee = true }
            }
            if hasUnderline {
                storage.removeAttribute(.underlineStyle, range: range)
            } else {
                storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            }
        case .fontSize:
            // Keep bold and italic: only the size changes.
            let size = CGFloat(pointSize ?? Int(baseFont.pointSize))
            storage.enumerateAttribute(.font, in: range) { value, sub, _ in
                let font = (value as? NSFont) ?? baseFont
                storage.addAttribute(.font, value: NSFontManager.shared.convert(font, toSize: size), range: sub)
            }
        }
        storage.endEditing()
        didChangeText()
    }

    private func applyToTypingAttributes(_ format: ScriptEditorFormat, pointSize: Int?) {
        var attributes = typingAttributes
        let font = (attributes[.font] as? NSFont) ?? baseFont
        switch format {
        case .bold, .italic:
            let mask: NSFontTraitMask = format == .bold ? .boldFontMask : .italicFontMask
            let trait: NSFontDescriptor.SymbolicTraits = format == .bold ? .bold : .italic
            attributes[.font] = font.fontDescriptor.symbolicTraits.contains(trait)
                ? NSFontManager.shared.convert(font, toNotHaveTrait: mask)
                : NSFontManager.shared.convert(font, toHaveTrait: mask)
        case .underline:
            if (attributes[.underlineStyle] as? Int) == NSUnderlineStyle.single.rawValue {
                attributes[.underlineStyle] = nil
            } else {
                attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            }
        case .fontSize:
            guard let size = pointSize, size >= 6, size <= 200 else { return }
            attributes[.font] = NSFontManager.shared.convert(font, toSize: CGFloat(size))
        }
        typingAttributes = attributes
    }

    deinit {
        stopObservingApplyFormat()
    }
}

// MARK: - SwiftUI wrapper

struct RichParagraphEditorView: NSViewRepresentable {
    @Binding var body: String
    @Binding var bodyRTF: Data?
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
        textView.textContainerInset = NSSize(width: 14, height: 12)

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

        let contentMatch = context.coordinator.lastBoundBody == body && context.coordinator.lastBoundRTF == bodyRTF
        if !contentMatch {
            // Loading never goes through didChangeText, so nothing here is reported back as an edit.
            if let rtf = bodyRTF, !rtf.isEmpty,
               let att = NSAttributedString(rtf: rtf, documentAttributes: nil) {
                // Keep the script's own fonts (bold, italic, sizes). Only the color follows the appearance, since
                // RTF stores it as a fixed RGB value.
                let styled = NSMutableAttributedString(attributedString: att)
                styled.addAttribute(.foregroundColor, value: color, range: NSRange(location: 0, length: styled.length))
                textView.textStorage?.setAttributedString(styled)
            } else {
                let att = NSAttributedString(string: body, attributes: [.font: font, .foregroundColor: color])
                textView.textStorage?.setAttributedString(att)
            }
            textView.typingAttributes = [.font: font, .foregroundColor: color]
            context.coordinator.lastBoundBody = body
            context.coordinator.lastBoundRTF = bodyRTF
        }

        textView.onContentDidChange = { plain, rtf in
            if plain != context.coordinator.lastBoundBody || rtf != context.coordinator.lastBoundRTF {
                context.coordinator.lastBoundBody = plain
                context.coordinator.lastBoundRTF = rtf
                self.body = plain
                self.bodyRTF = rtf
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject {
        var textView: NSTextView?
        var scrollView: NSScrollView?
        var lastBoundBody: String = ""
        var lastBoundRTF: Data?
    }
}
