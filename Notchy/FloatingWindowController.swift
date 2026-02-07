import AppKit
import SwiftUI

/// Height of the menu bar strip when the Mac has no notch (fallback).
private let fallbackNotchHeight: CGFloat = 28

/// UserDefaults key for preferred display (0 = main screen; otherwise CGDirectDisplayID as Int).
let preferredDisplayIDKey = "preferredDisplayID"

extension NSScreen {
    /// CGDirectDisplayID for this screen (from deviceDescription).
    var displayID: UInt32? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}

/// List of (displayID, displayName) for all screens, for picker/submenu. Option 0 = main; then one per screen.
func screensForSelection() -> [(id: Int, name: String)] {
    var list: [(id: Int, name: String)] = [(0, "Principal (tela do menu)")]
    let screens = NSScreen.screens
    let main = NSScreen.main
    for screen in screens {
        guard let did = screen.displayID else { continue }
        let id = Int(did)
        let name: String
        if #available(macOS 10.15, *) {
            name = screen.localizedName
        } else {
            name = "Display \(id)"
        }
        let isMain = screen === main
        list.append((id: id, name: isMain ? "\(name) (principal)" : name))
    }
    return list
}

/// Resolve NSScreen from stored preferred display ID (0 = main).
func screenForPreferredDisplayID(_ preferredID: Int) -> NSScreen? {
    if preferredID == 0 { return NSScreen.main }
    let screens = NSScreen.screens
    return screens.first { Int($0.displayID ?? 0) == preferredID } ?? NSScreen.main
}

/// Screen that contains the window (by center point). Used to detect current monitor when docking or after drag.
func screenContaining(window: NSWindow) -> NSScreen? {
    let center = CGPoint(x: window.frame.midX, y: window.frame.midY)
    return NSScreen.screens.first { $0.frame.contains(center) }
}

/// Union of all screens' visible frames (same coordinate system). Use when window is in free position so it can be dragged to any monitor.
func combinedVisibleFrameOfAllScreens() -> CGRect {
    let screens = NSScreen.screens
    guard let first = screens.first else { return .zero }
    var combined = first.visibleFrame
    for screen in screens.dropFirst() {
        combined = combined.union(screen.visibleFrame)
    }
    return combined
}

final class FloatingWindowController: ObservableObject {
    weak var window: NSWindow?
    private var screenObserver: NSObjectProtocol?
    /// Atraso antes de recolher, para evitar piscar quando o mouse fica na borda da área do notch.
    private var collapseWorkItem: DispatchWorkItem?

    /// When true, the window expands below the notch so you can paste and see the teleprompter.
    /// When there's text, collapse only via button; when empty, collapse on mouse exit too.
    @Published private(set) var isExpanded = true
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
        isExpanded = false
        updateWindowFrame(animated: true)
    }

    /// Saves current window width/height so they are restored when expanding from collapsed.
    private func persistCurrentWindowSizeBeforeCollapse() {
        guard let window = window, isExpanded else { return }
        let frame = window.frame
        if frame.width >= 128 {
            UserDefaults.standard.set(frame.width, forKey: "windowWidth")
        }
        if frame.height >= 200 {
            UserDefaults.standard.set(frame.height, forKey: "windowHeight")
        }
    }

    /// Call when Settings change (e.g. window width) to reposition the window.
    func refreshWindowFrame() {
        updateWindowFrame(animated: true)
    }

    /// Set which display the notch window should appear on (0 = main). Repositions immediately if pinned to notch.
    func setPreferredDisplayID(_ displayID: Int) {
        UserDefaults.standard.set(displayID, forKey: preferredDisplayIDKey)
        if isPinnedToNotch {
            updateWindowFrame(animated: true)
        }
    }

    /// When the user drags the window via the drag button, we use a free position instead of the notch.
    private static let windowPinnedToNotchKey = "windowPinnedToNotch"
    private static let windowFreeOriginXKey = "windowFreeOriginX"
    private static let windowFreeOriginYKey = "windowFreeOriginY"

    /// Whether the window is pinned to the notch (true) or placed freely (false).
    var isPinnedToNotch: Bool {
        get { UserDefaults.standard.object(forKey: Self.windowPinnedToNotchKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Self.windowPinnedToNotchKey) }
    }

    /// During drag we keep origin in memory to avoid UserDefaults + full update every frame (causes jitter).
    private var temporaryFreeOrigin: CGPoint?

    /// Set the window's free position (used when not pinned to notch). Call from the drag button gesture.
    /// During drag, use setWindowFreeOriginForDrag so we don't write to UserDefaults every frame.
    func setWindowFreeOrigin(_ origin: CGPoint) {
        UserDefaults.standard.set(origin.x, forKey: Self.windowFreeOriginXKey)
        UserDefaults.standard.set(origin.y, forKey: Self.windowFreeOriginYKey)
        UserDefaults.standard.set(false, forKey: Self.windowPinnedToNotchKey)
        temporaryFreeOrigin = nil
        updateWindowFrame(animated: false)
    }

    /// Update window position during drag only in memory; avoids jitter from UserDefaults + full layout each frame.
    func setWindowFreeOriginForDrag(_ origin: CGPoint) {
        if temporaryFreeOrigin == nil {
            UserDefaults.standard.set(false, forKey: Self.windowPinnedToNotchKey)
        }
        temporaryFreeOrigin = origin
        updateWindowFrame(animated: false)
    }

    /// Call when drag ends to commit the final position to UserDefaults.
    /// Also updates preferred display to the screen where the window ended up, so the app "knows" which monitor it's on.
    func commitWindowFreeOrigin(_ origin: CGPoint) {
        UserDefaults.standard.set(origin.x, forKey: Self.windowFreeOriginXKey)
        UserDefaults.standard.set(origin.y, forKey: Self.windowFreeOriginYKey)
        temporaryFreeOrigin = nil
        if let window = window, let screen = screenContaining(window: window), let displayID = screen.displayID {
            UserDefaults.standard.set(Int(displayID), forKey: preferredDisplayIDKey)
        }
    }

    /// Pin the window back to the notch (e.g. from a menu or double‑click on drag handle).
    /// If the window is on a different monitor, we update preferred display so it docks on the current screen.
    func pinWindowToNotch() {
        if let window = window, let screen = screenContaining(window: window), let displayID = screen.displayID {
            UserDefaults.standard.set(Int(displayID), forKey: preferredDisplayIDKey)
        }
        UserDefaults.standard.set(true, forKey: Self.windowPinnedToNotchKey)
        setExpanded(true)
        updateWindowFrame(animated: true)
    }

    /// Screen where the notch window should appear (from preferences or main).
    func targetScreen() -> NSScreen? {
        let preferred = UserDefaults.standard.integer(forKey: preferredDisplayIDKey)
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
        let showInCapture = UserDefaults.standard.bool(forKey: "showInScreenCapture")
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

        applyWindowOpacity()
        updateWindowFrame(animated: false)
        window.makeKeyAndOrderFront(nil)
    }

    /// Durante o arrasto do resize, usamos esses valores em vez de UserDefaults para evitar lag.
    private var temporaryResizeWidth: CGFloat?
    private var temporaryResizeHeight: CGFloat?

    /// Durante o arrasto do grip de resize: atualiza tamanho temporário sem escrever em UserDefaults.
    func setTemporaryResize(width: CGFloat?, height: CGFloat?) {
        temporaryResizeWidth = width
        temporaryResizeHeight = height
        updateWindowFrame(animated: false)
    }

    /// Largura definida nas Settings (0 = automática = largura total do notch).
    private func customWindowWidth() -> CGFloat {
        if let w = temporaryResizeWidth {
            if w <= 0 { return 0 }
            return min(1200, max(128, w))
        }
        let w = UserDefaults.standard.double(forKey: "windowWidth")
        if w > 0 { return min(1200, max(128, CGFloat(w))) }
        return 0
    }

    /// Altura expandida definida nas Settings (default 320).
    private func customExpandedHeight() -> CGFloat {
        if let h = temporaryResizeHeight {
            return min(600, max(200, h))
        }
        let h = UserDefaults.standard.double(forKey: "windowHeight")
        if h > 0 { return min(600, max(200, CGFloat(h))) }
        return 320
    }

    /// Computes the window frame (notch strip only, or expanded downward).
    private func notchFrame(screen: NSScreen, height: CGFloat) -> CGRect {
        let full = screen.frame
        let visible = screen.visibleFrame
        let menuBarHeight = full.maxY - visible.maxY
        let notchHeight = menuBarHeight > 0 ? menuBarHeight : fallbackNotchHeight
        let useHeight = height > notchHeight ? height : notchHeight
        let y = full.maxY - useHeight

        let notchMinX: CGFloat
        let notchWidth: CGFloat
        if #available(macOS 12.0, *),
           let leftArea = screen.auxiliaryTopLeftArea,
           let rightArea = screen.auxiliaryTopRightArea {
            notchMinX = full.minX + leftArea.width
            notchWidth = full.width - leftArea.width - rightArea.width
        } else {
            notchMinX = full.minX
            notchWidth = full.width
        }

        let customW = customWindowWidth()
        let windowWidth: CGFloat
        let windowX: CGFloat
        if customW > 0 {
            windowWidth = customW
            windowX = notchMinX + (notchWidth - customW) / 2
        } else {
            windowX = notchMinX
            windowWidth = notchWidth
        }

        return CGRect(x: windowX, y: y, width: windowWidth, height: useHeight)
    }

    /// Positions the window: collapsed in the notch strip or expanded so you can edit.
    private func updateWindowFrame(animated: Bool) {
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
                let freeX = CGFloat(UserDefaults.standard.double(forKey: Self.windowFreeOriginXKey))
                let freeY = CGFloat(UserDefaults.standard.double(forKey: Self.windowFreeOriginYKey))
                origin = CGPoint(x: freeX, y: freeY)
            }
            targetFrame.origin = origin
            // Clamp to the union of all screens' visible frames so the window can be dragged to any monitor
            let visible = combinedVisibleFrameOfAllScreens()
            targetFrame.origin.x = min(max(visible.minX, targetFrame.origin.x), visible.maxX - targetFrame.width)
            targetFrame.origin.y = min(max(visible.minY, targetFrame.origin.y), visible.maxY - targetFrame.height)
        }

        if animated {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.2
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(targetFrame, display: true)
            }, completionHandler: { [weak window] in
                window?.orderFrontRegardless()
            })
        } else if isDragging {
            // During drag only move origin to avoid layout thrashing and jitter
            window.setFrameOrigin(targetFrame.origin)
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
