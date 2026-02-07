import AppKit
import SwiftUI

/// Altura da faixa do notch (usada no hitTest para deixar cliques passarem na área do texto).
private let notchStripHeight: CGFloat = 32

/// NSView that reports mouse enter/exit to expand on hover and collapse on exit when there's no text.
/// hitTest: quando expandido, só "pegamos" a faixa do topo (notch) para hover; o resto passa para o texto.
/// Quando recolhido, somos nós que estamos sob o mouse para receber enter/exit.
private final class HoverTrackingView: NSView {
    var onMouseEnter: (() -> Void)?
    var onMouseExit: (() -> Void)?
    /// Quando true, a janela está expandida; aí só a faixa do topo (~notch) deve receber hit para hover.
    var isExpanded: Bool = true
    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        onMouseEnter?()
    }

    override func mouseExited(with event: NSEvent) {
        onMouseExit?()
    }

    /// Quando recolhido: retornamos self para o sistema considerar o mouse sobre a janela e enviar enter/exit.
    /// Quando expandido: só a faixa do topo (notch) retorna self; o resto nil para cliques irem ao texto.
    override func hitTest(_ point: NSPoint) -> NSView? {
        if isExpanded && bounds.height > notchStripHeight {
            let topStrip = bounds.maxY - notchStripHeight
            if point.y < topStrip { return nil }
        }
        return self
    }

    deinit {
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
    }
}

/// Finds the NSWindow that contains this view and passes it to the controller.
/// Also adds hover tracking so the window expands when the mouse is over the notch.
struct WindowAccessor: NSViewRepresentable {
    let windowController: FloatingWindowController

    func makeNSView(context: Context) -> NSView {
        let view = HoverTrackingView()
        view.wantsLayer = false
        view.isExpanded = windowController.isExpanded
        view.onMouseEnter = { [weak windowController] in
            windowController?.setExpanded(true)
        }
        view.onMouseExit = { [weak windowController] in
            windowController?.setExpanded(false)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? HoverTrackingView {
            view.isExpanded = windowController.isExpanded
        }
        // Só repassar a janela quando for realmente nova (evita reposicionar a cada re-render do SwiftUI).
        if let window = nsView.window, windowController.window !== window {
            DispatchQueue.main.async {
                windowController.setWindow(window)
            }
        }
    }
}
