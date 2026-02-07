import SwiftUI
import AppKit

/// Notification when user pastes in the teleprompter. userInfo["pastedText"] = pasted string.
extension Notification.Name {
    static let teleprompterDidPaste = Notification.Name("teleprompterDidPaste")
}

/// NSTextView que, ao colar, insere apenas texto puro (sem formatação), mantendo quebras de linha.
/// Também desativa o scroll automático para seleção/range, evitando o "salto" ao mudar de parágrafo
/// quando o monitor de voz está ativo (o scroll é controlado apenas pelo ScrollController).
/// Posts .teleprompterDidPaste so the app can create a script from the pasted text.
private final class PlainTextPasteTextView: NSTextView {
    override func paste(_ sender: Any?) {
        guard let pasteboard = NSPasteboard.general.string(forType: .string), !pasteboard.isEmpty else {
            super.paste(sender)
            return
        }
        replaceCharacters(in: selectedRange(), with: pasteboard)
        NotificationCenter.default.post(
            name: .teleprompterDidPaste,
            object: self,
            userInfo: ["pastedText": pasteboard]
        )
    }

    override func scrollRangeToVisible(_ range: NSRange) {
        // Só faz scroll para manter o cursor de edição visível (insertion point).
        // Para seleções (range.length > 0), não fazemos scroll — evita o mini salto ao mudar de
        // parágrafo quando o monitor de voz está ativo; o scroll de leitura fica a cargo do ScrollController.
        if range.length == 0 {
            super.scrollRangeToVisible(range)
        }
    }
}

/// 0 = left, 1 = center, 2 = right, 3 = justify
struct TeleprompterTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var scrollOffset: CGFloat
    var fontSize: Double
    var textColor: Color
    var textOpacity: Double = 1
    var alignmentMode: Int = 0

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
        scrollView.scrollerStyle = .overlay  // scrollbar flutua sobre o texto, não ocupa espaço
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.contentView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

        let textView = PlainTextPasteTextView()
        textView.isEditable = true
        textView.isSelectable = true
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
        textView.layoutManager?.allowsNonContiguousLayout = false  // layout contínuo evita re-layout ao rolar que pode causar salto

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = nsAlignment
        textView.defaultParagraphStyle = paragraphStyle
        textView.typingAttributes[.paragraphStyle] = paragraphStyle

        scrollView.documentView = textView
        textView.delegate = context.coordinator
        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView
        context.coordinator.setupScrollObservation(scrollView: scrollView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        let coordinator = context.coordinator
        if !coordinator.ignoreNextSyncFromBinding {
            if textView.string != text {
                // Nunca sobrescrever conteúdo do text view com string vazia (ex.: colar depois
                // que AppStorage ainda não atualizou). Se o binding veio vazio e o text view tem
                // conteúdo, corrige o binding em vez de apagar.
                if text.isEmpty && !textView.string.isEmpty {
                    coordinator.parent.text = textView.string
                } else {
                    textView.string = text
                }
            }
        } else {
            coordinator.ignoreNextSyncFromBinding = false
        }
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

        // Só aplica scrollOffset quando diferente da posição atual (evita resetar scroll manual do usuário).
        let currentY = scrollView.contentView.bounds.origin.y
        if abs(currentY - scrollOffset) > 0.5 {
            var clipViewBounds = scrollView.contentView.bounds
            clipViewBounds.origin.y = scrollOffset
            scrollView.contentView.scroll(to: clipViewBounds.origin)
            scrollView.reflectScrolledClipView(scrollView.contentView)  // mantém scrollers e estado consistentes
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: TeleprompterTextView
        weak var textView: NSTextView?
        weak var scrollView: NSScrollView?
        /// Quando true, o próximo updateNSView não deve sobrescrever string do text view (evita colar e ficar vazio).
        var ignoreNextSyncFromBinding = false
        private var scrollBoundsObserver: NSObjectProtocol?

        init(_ parent: TeleprompterTextView) {
            self.parent = parent
        }

        deinit {
            if let observer = scrollBoundsObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        func setupScrollObservation(scrollView: NSScrollView) {
            scrollView.contentView.postsBoundsChangedNotifications = true
            scrollBoundsObserver = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: scrollView.contentView,
                queue: .main
            ) { [weak self] _ in
                guard let self = self, let scrollView = self.scrollView else { return }
                let newOffset = scrollView.contentView.bounds.origin.y
                self.parent.scrollOffset = newOffset
            }
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = textView else { return }
            ignoreNextSyncFromBinding = true
            parent.text = textView.string
        }
    }
}
