import AppKit
import SwiftUI

final class FloatingWindowController: ObservableObject {
    weak var window: NSWindow?
    private var screenObserver: NSObjectProtocol?
    /// Atraso antes de recolher, para evitar piscar quando o mouse fica na borda da área do notch.
    private var collapseWorkItem: DispatchWorkItem?

    /// When true, the window expands below the notch so you can paste and see the teleprompter.
    /// When there's text, collapse only via button; when empty, collapse on mouse exit too.
    @Published private(set) var isExpanded = true
    /// True from collapseNow() until the frame animation finishes; keeps bar shape (no capsule) during shrink.
    @Published private(set) var isCollapseAnimationInProgress = false
    /// True while the user is dragging the resize grip; used to freeze bar layout and avoid height jump.
    @Published private(set) var isWindowResizing = false
    /// When true, we don't auto-collapse on mouse exit (so pasted text stays visible).
    var hasPrompterText: Bool = false

    func setWindow(_ window: NSWindow?) {
        guard self.window !== window else { return }
        self.window = window
        configureWindow()
        setupScreenObserver()
    }

    /// Call when mouse enters the notch (expand) or leaves (collapse only if there's no text).
    func setExpanded(_ expanded: Bool) {
        collapseWorkItem?.cancel()
        collapseWorkItem = nil

        if expanded {
            guard isExpanded != true else { return }
            isExpanded = true
            updateWindowFrame(animated: true)
        } else {
            guard !hasPrompterText else { return }
            let item = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                guard self.isExpanded else { return }
                self.persistCurrentWindowSizeBeforeCollapse()
                self.isExpanded = false
                self.updateWindowFrame(animated: true)
            }
            collapseWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55, execute: item)
        }
    }

    /// Called by the view when prompter text changes; when true, we skip auto-collapse on mouse exit.
    func setHasPrompterText(_ has: Bool) {
        hasPrompterText = has
    }

    /// Expand and bring window to front (e.g. from menu or shortcut when it's in the notch).
    func showTeleprompter() {
        setExpanded(true)
        window?.makeKeyAndOrderFront(nil)
    }

    /// Collapse immediately (e.g. when user taps the collapse button), without hover delay.
    func collapseNow() {
        collapseWorkItem?.cancel()
        collapseWorkItem = nil
        guard isExpanded else { return }
        persistCurrentWindowSizeBeforeCollapse()
        isCollapseAnimationInProgress = true
        isExpanded = false
        updateWindowFrame(animated: true) { [weak self] in
            self?.isCollapseAnimationInProgress = false
        }
    }

    /// Saves current window width/height so they are restored when expanding from collapsed.
    private func persistCurrentWindowSizeBeforeCollapse() {
        guard let window = window, isExpanded else { return }
        let frame = window.frame
        if frame.width >= Self.minWindowWidth {
            UserDefaults.standard.set(frame.width, forKey: NotchyKeys.windowWidth)
        }
        if frame.height >= 200 {
            UserDefaults.standard.set(frame.height, forKey: NotchyKeys.windowHeight)
        }
    }

    /// Call when Settings change (e.g. window width) to reposition the window.
    func refreshWindowFrame() {
        updateWindowFrame(animated: true)
    }

    /// Set which display the notch window should appear on (0 = main). Repositions immediately if pinned to notch.
    func setPreferredDisplayID(_ displayID: Int) {
        UserDefaults.standard.set(displayID, forKey: NotchyKeys.preferredDisplayID)
        if isPinnedToNotch {
            updateWindowFrame(animated: true)
        }
    }

    /// Whether the window is pinned to the notch (true) or placed freely (false).
    var isPinnedToNotch: Bool {
        get { UserDefaults.standard.object(forKey: NotchyKeys.windowPinnedToNotch) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: NotchyKeys.windowPinnedToNotch) }
    }

    /// During drag we keep origin in memory to avoid UserDefaults + full update every frame (causes jitter).
    private var temporaryFreeOrigin: CGPoint?

    /// Set the window's free position (used when not pinned to notch). Call from the drag button gesture.
    /// During drag, use setWindowFreeOriginForDrag so we don't write to UserDefaults every frame.
    func setWindowFreeOrigin(_ origin: CGPoint) {
        UserDefaults.standard.set(origin.x, forKey: NotchyKeys.windowFreeOriginX)
        UserDefaults.standard.set(origin.y, forKey: NotchyKeys.windowFreeOriginY)
        UserDefaults.standard.set(false, forKey: NotchyKeys.windowPinnedToNotch)
        temporaryFreeOrigin = nil
        updateWindowFrame(animated: false)
    }

    /// Update window position during drag only in memory; avoids jitter from UserDefaults + full layout each frame.
    func setWindowFreeOriginForDrag(_ origin: CGPoint) {
        if temporaryFreeOrigin == nil {
            UserDefaults.standard.set(false, forKey: NotchyKeys.windowPinnedToNotch)
        }
        temporaryFreeOrigin = origin
        updateWindowFrame(animated: false)
    }

    /// Call when drag ends to commit the final position to UserDefaults.
    /// Also updates preferred display to the screen where the window ended up, so the app "knows" which monitor it's on.
    func commitWindowFreeOrigin(_ origin: CGPoint) {
        UserDefaults.standard.set(origin.x, forKey: NotchyKeys.windowFreeOriginX)
        UserDefaults.standard.set(origin.y, forKey: NotchyKeys.windowFreeOriginY)
        temporaryFreeOrigin = nil
        if let window = window, let screen = screenContaining(window: window), let displayID = screen.displayID {
            UserDefaults.standard.set(Int(displayID), forKey: NotchyKeys.preferredDisplayID)
        }
    }

    /// Pin the window back to the notch (e.g. from a menu or double‑click on drag handle).
    /// If the window is on a different monitor, we update preferred display so it docks on the current screen.
    func pinWindowToNotch() {
        if let window = window, let screen = screenContaining(window: window), let displayID = screen.displayID {
            UserDefaults.standard.set(Int(displayID), forKey: NotchyKeys.preferredDisplayID)
        }
        UserDefaults.standard.set(true, forKey: NotchyKeys.windowPinnedToNotch)
        setExpanded(true)
        updateWindowFrame(animated: true)
    }

    /// Screen where the notch window should appear (from preferences or main).
    func targetScreen() -> NSScreen? {
        let preferred = UserDefaults.standard.integer(forKey: NotchyKeys.preferredDisplayID)
        return screenForPreferredDisplayID(preferred)
    }

    /// Returns true if the window is currently near the notch strip (e.g. user dragged it back up).
    /// When true, the drag button can snap the window back into the notch on drop.
    func shouldSnapToNotch() -> Bool {
        guard let window = window, let screen = targetScreen() else { return false }
        let frame = window.frame
        let full = screen.frame
        let notchMinX: CGFloat
        let notchMaxX: CGFloat
        if #available(macOS 12.0, *),
           let leftArea = screen.auxiliaryTopLeftArea,
           let rightArea = screen.auxiliaryTopRightArea {
            notchMinX = full.minX + leftArea.width
            notchMaxX = full.maxX - rightArea.width
        } else {
            notchMinX = full.minX
            notchMaxX = full.maxX
        }
        let topOfNotch = full.maxY
        let snapThreshold: CGFloat = 80
        let windowTop = frame.maxY
        let nearTop = windowTop >= topOfNotch - snapThreshold
        let horizontalOverlap = frame.minX < notchMaxX && frame.maxX > notchMinX
        return nearTop && horizontalOverlap
    }

    /// Current window frame (for drag-to-move). Nil if no window.
    func currentWindowFrame() -> CGRect? {
        window?.frame
    }

    /// Apply "show in screen capture" preference. When off (stealth), window is excluded from recordings/screenshots.
    func applySharingType() {
        let showInCapture = UserDefaults.standard.bool(forKey: NotchyKeys.showInScreenCapture)
        window?.sharingType = showInCapture ? .readOnly : .none
    }

    /// Window opacity is applied only to the background in ContentView (not alphaValue), so text and controls stay visible.
    func applyWindowOpacity() {
        window?.alphaValue = 1
    }

    private func configureWindow() {
        guard let window = window else { return }

        // Off so the resize grip only resizes; use the drag handle button to move the window.
        window.isMovableByWindowBackground = false
        window.isOpaque = false
        window.hasShadow = false
        window.backgroundColor = .clear
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        // Nível será ajustado em updateWindowFrame: recolhido = acima da menu bar para hover; expandido = mesmo nível.
        applySharingType()
        // Precisamos receber mouse moved mesmo quando a janela não é key (ex.: após diálogo do mic)
        // para o hover no notch expandir a janela.
        window.acceptsMouseMovedEvents = true

        // Permite redimensionar até 340pt para a barra em duas linhas caber sem cortar bordas.
        window.minSize = NSSize(width: Self.minWindowWidth, height: 200)

        applyWindowOpacity()
        updateWindowFrame(animated: false)
        window.makeKeyAndOrderFront(nil)
    }

    /// Durante o arrasto do resize, usamos esses valores em vez de UserDefaults para evitar lag.
    private var temporaryResizeWidth: CGFloat?
    private var temporaryResizeHeight: CGFloat?

    /// Centro X e topo Y no início do resize; mantidos durante todo o arrasto para crescimento pelo centro (sem drift).
    private var temporaryResizeAnchorCenterX: CGFloat?
    private var temporaryResizeAnchorTopY: CGFloat?

    /// Chamar no mouseDown do grip de resize para fixar o centro horizontal e o topo como âncora.
    func beginResizeAnchor(centerX: CGFloat, topY: CGFloat) {
        temporaryResizeAnchorCenterX = centerX
        temporaryResizeAnchorTopY = topY
    }

    /// Durante o arrasto do grip de resize: atualiza tamanho temporário sem escrever em UserDefaults.
    func setTemporaryResize(width: CGFloat?, height: CGFloat?) {
        let wasResizing = temporaryResizeWidth != nil || temporaryResizeHeight != nil
        temporaryResizeWidth = width
        temporaryResizeHeight = height
        let nowResizing = width != nil || height != nil
        if nowResizing != wasResizing {
            isWindowResizing = nowResizing
        }
        updateWindowFrame(animated: false)
    }

    /// Persiste largura/altura no UserDefaults e limpa o resize temporário (chamar ao soltar o grip).
    func commitResize(width: CGFloat, height: CGFloat) {
        let w = min(1200, max(Self.minWindowWidth, width))
        let h = min(600, max(200, height))
        UserDefaults.standard.set(w, forKey: NotchyKeys.windowWidth)
        UserDefaults.standard.set(h, forKey: NotchyKeys.windowHeight)
        setTemporaryResize(width: nil, height: nil)
        temporaryResizeAnchorCenterX = nil
        temporaryResizeAnchorTopY = nil
    }

    /// Largura mínima da janela expandida; abaixo disso as bordas e o conteúdo cortam.
    private static let minWindowWidth: CGFloat = 340
    /// Largura da faixa recolhida em telas sem notch (monitor externo); evita full width.
    private static let collapsedStripWidthNoNotch: CGFloat = 400

    /// Largura definida nas Settings (0 = automática = largura total do notch).
    private func customWindowWidth() -> CGFloat {
        if let w = temporaryResizeWidth {
            if w <= 0 { return 0 }
            return min(1200, max(Self.minWindowWidth, w))
        }
        let w = UserDefaults.standard.double(forKey: NotchyKeys.windowWidth)
        if w > 0 { return min(1200, max(Self.minWindowWidth, CGFloat(w))) }
        return 0
    }

    /// Altura expandida definida nas Settings (default 320).
    private func customExpandedHeight() -> CGFloat {
        if let h = temporaryResizeHeight {
            return min(600, max(200, h))
        }
        let h = UserDefaults.standard.double(forKey: NotchyKeys.windowHeight)
        if h > 0 { return min(600, max(200, CGFloat(h))) }
        return 320
    }

    /// Computes the window frame (notch strip only, or expanded downward).
    /// When collapsed: with notch uses full notch width; without notch (external display) uses a fixed strip width centered.
    /// When expanded, uses custom width but clamps so the window stays centered in the notch and doesn't open "to the side".
    private func notchFrame(screen: NSScreen, height: CGFloat) -> CGRect {
        let full = screen.frame
        let visible = screen.visibleFrame
        let menuBarHeight = full.maxY - visible.maxY
        let notchHeight = menuBarHeight > 0 ? menuBarHeight : fallbackNotchHeight
        let useHeight = height > notchHeight ? height : notchHeight
        let y = full.maxY - useHeight
        let isCollapsed = (height <= notchHeight + 1) // collapsed = only the strip

        let hasNotch: Bool
        let notchMinX: CGFloat
        let notchWidth: CGFloat
        if #available(macOS 12.0, *),
           let leftArea = screen.auxiliaryTopLeftArea,
           let rightArea = screen.auxiliaryTopRightArea {
            hasNotch = true
            notchMinX = full.minX + leftArea.width
            notchWidth = full.width - leftArea.width - rightArea.width
        } else {
            hasNotch = false
            notchMinX = full.minX
            notchWidth = full.width
        }

        let screenCenterX = visible.minX + visible.width / 2
        let customW = customWindowWidth()
        let windowWidth: CGFloat
        let windowX: CGFloat
        if isCollapsed {
            if hasNotch {
                // Com notch: largura total da faixa do notch
                windowWidth = notchWidth
                windowX = notchMinX
            } else {
                // Sem notch (monitor externo): faixa com largura fixa, centralizada
                let w = min(Self.collapsedStripWidthNoNotch, visible.width)
                windowWidth = max(Self.minWindowWidth, w)
                let centerX = screenCenterX - windowWidth / 2
                windowX = max(visible.minX, min(visible.maxX - windowWidth, centerX))
            }
        } else if customW > 0 {
            // Expandido: largura custom; centralizado na tela (não na borda do notch) para crescer pelos dois lados
            let effectiveW = max(Self.minWindowWidth, min(1200, customW))
            windowWidth = effectiveW
            let centerX = screenCenterX - effectiveW / 2
            windowX = max(visible.minX, min(visible.maxX - effectiveW, centerX))
        } else {
            // Auto: largura total do notch; se o notch for mais estreito que 340pt, usar 340pt centralizado na tela
            if notchWidth >= Self.minWindowWidth {
                windowWidth = notchWidth
                windowX = notchMinX
            } else {
                windowWidth = Self.minWindowWidth
                let centerX = screenCenterX - windowWidth / 2
                windowX = max(visible.minX, min(visible.maxX - windowWidth, centerX))
            }
        }

        return CGRect(x: windowX, y: y, width: windowWidth, height: useHeight)
    }

    /// Positions the window: collapsed in the notch strip or expanded so you can edit.
    private func updateWindowFrame(animated: Bool, completion: (() -> Void)? = nil) {
        guard let window = window, let screen = targetScreen() else { return }

        // Recolhido: janela acima da menu bar para receber hover no notch. Expandido: mesmo nível da menu bar.
        let menuLevel = Int(CGWindowLevelForKey(.mainMenuWindow))
        let aboveMenuLevel = Int(CGWindowLevelForKey(.statusWindow)) + 1
        window.level = NSWindow.Level(rawValue: isExpanded ? menuLevel : aboveMenuLevel)

        let full = screen.frame
        let visible = screen.visibleFrame
        let menuBarHeight = full.maxY - visible.maxY
        let notchHeight = menuBarHeight > 0 ? menuBarHeight : fallbackNotchHeight
        let height = isExpanded ? customExpandedHeight() : notchHeight
        var targetFrame = notchFrame(screen: screen, height: height)
        let isDragging = temporaryFreeOrigin != nil
        if !isPinnedToNotch {
            let origin: CGPoint
            if let temp = temporaryFreeOrigin {
                origin = temp
            } else {
                let freeX = CGFloat(UserDefaults.standard.double(forKey: NotchyKeys.windowFreeOriginX))
                let freeY = CGFloat(UserDefaults.standard.double(forKey: NotchyKeys.windowFreeOriginY))
                origin = CGPoint(x: freeX, y: freeY)
            }
            // Never open at (0,0) — treat as "use notch" so window opens centered in notch, not in corner
            let visible = combinedVisibleFrameOfAllScreens()
            let isInvalidOrigin = (origin.x == 0 && origin.y == 0) || !visible.contains(CGPoint(x: origin.x + targetFrame.width / 2, y: origin.y + targetFrame.height / 2))
            if isInvalidOrigin && !isDragging {
                // Use notch position for this open (last position was invalid or never set)
                targetFrame = notchFrame(screen: screen, height: height)
            } else {
                targetFrame.origin = origin
                // Clamp to the union of all screens' visible frames so the window can be dragged to any monitor
                targetFrame.origin.x = min(max(visible.minX, targetFrame.origin.x), visible.maxX - targetFrame.width)
                targetFrame.origin.y = min(max(visible.minY, targetFrame.origin.y), visible.maxY - targetFrame.height)
            }
        }

        let isResizing = temporaryResizeWidth != nil || temporaryResizeHeight != nil
        if animated {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.2
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(targetFrame, display: true)
            }, completionHandler: { [weak window] in
                window?.orderFrontRegardless()
                completion?()
            })
        } else if isDragging {
            // During drag only move origin to avoid layout thrashing and jitter
            window.setFrameOrigin(targetFrame.origin)
        } else if isResizing {
            // Durante o resize: manter o centro horizontal e o topo fixos (âncora definida no mouseDown do grip).
            let centerX = temporaryResizeAnchorCenterX ?? (window.frame.origin.x + window.frame.width / 2)
            let top = temporaryResizeAnchorTopY ?? (window.frame.origin.y + window.frame.height)
            let newOrigin = CGPoint(x: centerX - targetFrame.width / 2, y: top - targetFrame.height)
            let smoothFrame = CGRect(origin: newOrigin, size: CGSize(width: targetFrame.width, height: targetFrame.height))
            window.setFrame(smoothFrame, display: false)
            if !isPinnedToNotch {
                UserDefaults.standard.set(newOrigin.x, forKey: NotchyKeys.windowFreeOriginX)
                UserDefaults.standard.set(newOrigin.y, forKey: NotchyKeys.windowFreeOriginY)
            }
        } else {
            window.setFrame(targetFrame, display: true)
            window.orderFrontRegardless()
        }
    }

    /// Reposition when screen layout changes (e.g. display connected).
    private func positionInNotch() {
        updateWindowFrame(animated: false)
    }

    private func setupScreenObserver() {
        if let o = screenObserver {
            NotificationCenter.default.removeObserver(o)
        }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.positionInNotch()
        }
    }

    deinit {
        screenObserver.map { NotificationCenter.default.removeObserver($0) }
    }
}
