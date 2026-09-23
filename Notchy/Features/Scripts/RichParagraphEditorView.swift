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
    /// Quando true, o próximo didChangeText não reporta (evita commit ao carregar conteúdo).
    var skipNextReport = false

    override func didChangeText() {
        super.didChangeText()
        if skipNextReport {
            skipNextReport = false
            return
        }
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
        let effectiveRange = range.length > 0 ? range : NSRange(location: 0, length: storage.length)
        guard effectiveRange.length > 0 else { return }

        storage.beginEditing()
        defer { storage.endEditing() }

        switch format {
        case .bold:
            storage.enumerateAttribute(.font, in: effectiveRange) { value, range, _ in
                let font = (value as? NSFont) ?? baseFont
                let traits = font.fontDescriptor.symbolicTraits
                let newFont = traits.contains(.bold)
                    ? NSFontManager.shared.convert(font, toNotHaveTrait: .boldFontMask)
                    : NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
                storage.addAttribute(.font, value: newFont, range: range)
            }
        case .italic:
            storage.enumerateAttribute(.font, in: effectiveRange) { value, range, _ in
                let font = (value as? NSFont) ?? baseFont
                let traits = font.fontDescriptor.symbolicTraits
                let newFont = traits.contains(.italic)
                    ? NSFontManager.shared.convert(font, toNotHaveTrait: .italicFontMask)
                    : NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
                storage.addAttribute(.font, value: newFont, range: range)
            }
        case .underline:
            var hasUnderline = false
            storage.enumerateAttribute(.underlineStyle, in: effectiveRange) { value, _, stop in
                if (value as? Int) == NSUnderlineStyle.single.rawValue { hasUnderline = true; stop.pointee = true }
            }
            if hasUnderline {
                storage.removeAttribute(.underlineStyle, range: effectiveRange)
            } else {
                storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: effectiveRange)
            }
        case .fontSize:
            guard let size = pointSize, size >= 6, size <= 200 else { return }
            let newFont = NSFont(descriptor: baseFont.fontDescriptor, size: CGFloat(size)) ?? baseFont
            storage.addAttribute(.font, value: newFont, range: effectiveRange)
        }
        reportContent()
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
            textView.skipNextReport = true
            if let rtf = bodyRTF, !rtf.isEmpty,
               let att = NSAttributedString(rtf: rtf, documentAttributes: nil) {
                textView.textStorage?.setAttributedString(att)
            } else {
                let att = NSAttributedString(string: body, attributes: [.font: font, .foregroundColor: color])
                textView.textStorage?.setAttributedString(att)
            }
            textView.font = font
            textView.textColor = color
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
