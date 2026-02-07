import AppKit
import SwiftUI

// MARK: - Control bar button

/// Botão da barra de controles (mic, play, recolher) — tamanho fixo para alinhamento.
struct ControlBarButton: View {
    let icon: String
    let active: Bool
    let action: () -> Void
    @AppStorage(NotchyKeys.buttonColorHex) private var buttonColorHex = "FFFFFF"
    @AppStorage(NotchyKeys.buttonOpacity) private var buttonOpacity: Double = 1

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: icon == "chevron.up" ? .semibold : .regular))
                .foregroundColor(buttonColorFromHex(buttonColorHex).opacity((active ? 0.9 : 0.5) * buttonOpacity))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Resize handle (AppKit)

fileprivate final class ResizeHandleMouseView: NSView {
    weak var windowController: FloatingWindowController?
    private var dragStartFrame: CGRect = .zero
    private var dragStartLocation: NSPoint = .zero
    private var trackingArea: NSTrackingArea?
    private static let minWidth: CGFloat = 340
    private static let maxWidth: CGFloat = 1200
    private static let minHeight: CGFloat = 200
    private static let maxHeight: CGFloat = 600

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingArea.map { removeTrackingArea($0) }
        let area = NSTrackingArea(rect: bounds, options: [.activeAlways, .mouseEnteredAndExited], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        NSCursor.resizeUpDown.push()
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.pop()
    }

    override func mouseDown(with event: NSEvent) {
        guard let window = window, let controller = windowController else { return }
        dragStartFrame = window.frame
        dragStartLocation = NSEvent.mouseLocation
        let centerX = dragStartFrame.origin.x + dragStartFrame.width / 2
        let topY = dragStartFrame.origin.y + dragStartFrame.height
        controller.beginResizeAnchor(centerX: centerX, topY: topY)
    }

    override func mouseDragged(with event: NSEvent) {
        guard windowController != nil, let _ = window else { return }
        let current = NSEvent.mouseLocation
        let deltaX = current.x - dragStartLocation.x
        let deltaY = dragStartLocation.y - current.y
        var newW = dragStartFrame.width + deltaX
        var newH = dragStartFrame.height + deltaY
        newW = min(Self.maxWidth, max(Self.minWidth, newW))
        newH = min(Self.maxHeight, max(Self.minHeight, newH))
        windowController?.setTemporaryResize(width: newW, height: newH)
    }

    override func mouseUp(with event: NSEvent) {
        guard let window = window, let controller = windowController else { return }
        controller.commitResize(width: window.frame.width, height: window.frame.height)
    }
}

fileprivate struct ResizeHandleRepresentable: NSViewRepresentable {
    let windowController: FloatingWindowController

    func makeNSView(context: Context) -> NSView {
        let v = ResizeHandleMouseView()
        v.windowController = windowController
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? ResizeHandleMouseView else { return }
        view.windowController = windowController
    }
}

struct ResizeHandleView: View {
    @EnvironmentObject var windowController: FloatingWindowController
    @AppStorage(NotchyKeys.buttonOpacity) private var buttonOpacity: Double = 1
    @AppStorage(NotchyKeys.buttonColorHex) private var buttonColorHex = "FFFFFF"

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.clear
            ResizeGripShape()
                .stroke(buttonColorFromHex(buttonColorHex).opacity(0.5 * buttonOpacity), lineWidth: 1.5)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
                .frame(width: 28, height: 28)
                .padding(4)
            ResizeHandleRepresentable(windowController: windowController)
        }
        .frame(width: 32, height: 32)
    }
}

// MARK: - Drag handle (AppKit)

fileprivate final class DragHandleMouseView: NSView {
    weak var windowController: FloatingWindowController?
    var onMouseEnter: (() -> Void)?
    var onMouseExit: (() -> Void)?
    private var dragStartWindowOrigin: CGPoint?
    private var dragStartScreenLocation: NSPoint?
    private var didDrag = false
    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingArea.map { removeTrackingArea($0) }
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
        NSCursor.openHand.push()
        onMouseEnter?()
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.pop()
        onMouseExit?()
    }

    override func mouseDown(with event: NSEvent) {
        guard let window = window else { return }
        dragStartWindowOrigin = window.frame.origin
        dragStartScreenLocation = NSEvent.mouseLocation
        didDrag = false
        UserDefaults.standard.set(false, forKey: NotchyKeys.windowPinnedToNotch)
    }

    override func mouseDragged(with event: NSEvent) {
        guard window != nil,
              let controller = windowController,
              let startOrigin = dragStartWindowOrigin,
              let startScreen = dragStartScreenLocation else { return }
        didDrag = true
        let currentScreen = NSEvent.mouseLocation
        let dx = currentScreen.x - startScreen.x
        let dy = currentScreen.y - startScreen.y
        let newOrigin = CGPoint(x: startOrigin.x + dx, y: startOrigin.y + dy)
        controller.setWindowFreeOriginForDrag(newOrigin)
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            dragStartWindowOrigin = nil
            dragStartScreenLocation = nil
        }
        guard let window = window, let controller = windowController else { return }
        let finalOrigin = window.frame.origin
        controller.commitWindowFreeOrigin(finalOrigin)
        if event.clickCount == 2 && !didDrag {
            controller.pinWindowToNotch()
        } else if controller.shouldSnapToNotch() {
            controller.pinWindowToNotch()
        }
    }
}

struct DragHandleRepresentable: NSViewRepresentable {
    let windowController: FloatingWindowController
    var onMouseEnter: (() -> Void)? = nil
    var onMouseExit: (() -> Void)? = nil

    func makeNSView(context: Context) -> NSView {
        let v = DragHandleMouseView()
        v.windowController = windowController
        v.onMouseEnter = onMouseEnter
        v.onMouseExit = onMouseExit
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? DragHandleMouseView else { return }
        view.windowController = windowController
        view.onMouseEnter = onMouseEnter
        view.onMouseExit = onMouseExit
    }
}

fileprivate struct DragWindowButton: View {
    let windowController: FloatingWindowController
    @AppStorage(NotchyKeys.buttonColorHex) private var buttonColorHex = "FFFFFF"
    @AppStorage(NotchyKeys.buttonOpacity) private var buttonOpacity: Double = 1

    var body: some View {
        ZStack {
            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                .font(.system(size: 12))
                .foregroundColor(buttonColorFromHex(buttonColorHex).opacity(0.7 * buttonOpacity))
            DragHandleRepresentable(windowController: windowController)
        }
        .frame(width: 28, height: 28)
        .contentShape(Rectangle())
        .help(String(localized: "drag_to_move_help"))
    }
}

// MARK: - Control bar

/// Barra de controles: full (todos os botões), wrapped (duas linhas) ou extra-compact (só arrastar + menu).
struct ControlBarView: View {
    let barWidth: CGFloat
    let compactThreshold: CGFloat
    let extraCompactThreshold: CGFloat
    @Binding var voiceControlEnabled: Bool
    @Binding var autoScrollPlaying: Bool
    @Binding var mirrorMode: Int
    @Binding var textAlignment: Int
    let mirrorModeIcon: String
    let mirrorModeHelp: String
    let alignmentIcon: String
    let alignmentHelp: String
    let windowController: FloatingWindowController
    @AppStorage(NotchyKeys.buttonColorHex) private var buttonColorHex = "FFFFFF"
    @AppStorage(NotchyKeys.buttonOpacity) private var buttonOpacity: Double = 1

    private var useExtraCompact: Bool { barWidth < extraCompactThreshold }
    private var useWrapped: Bool { barWidth < compactThreshold && barWidth >= extraCompactThreshold }
    private var barHeight: CGFloat { useWrapped ? 76 : 36 }

    var body: some View {
        ZStack {
            DragHandleRepresentable(windowController: windowController)
                .frame(maxWidth: .infinity)
                .frame(height: barHeight)
            if useExtraCompact {
                extraCompactBar
            } else if useWrapped {
                wrappedBar
            } else {
                fullBar
            }
        }
    }

    private var fullBar: some View {
        HStack(alignment: .center, spacing: 12) {
            DragWindowButton(windowController: windowController)
            ControlBarButton(icon: voiceControlEnabled ? "mic.fill" : "mic.slash.fill", active: voiceControlEnabled) {
                voiceControlEnabled.toggle()
            }
            .help(voiceControlEnabled ? String(localized: "voice_disable") : String(localized: "voice_enable"))
            ControlBarButton(icon: autoScrollPlaying ? "pause.fill" : "play.fill", active: autoScrollPlaying) {
                autoScrollPlaying.toggle()
            }
            .help(autoScrollPlaying ? String(localized: "scroll_pause") : String(localized: "scroll_auto"))
            ControlBarButton(icon: mirrorModeIcon, active: mirrorMode != 0) {
                mirrorMode = (mirrorMode + 1) % 4
            }
            .help(mirrorModeHelp)
            ControlBarButton(icon: alignmentIcon, active: textAlignment != 0) {
                textAlignment = (textAlignment + 1) % 4
            }
            .help(alignmentHelp)
            Spacer(minLength: 0)
            ControlBarButton(icon: "gearshape", active: true) {
                NSApplication.shared.sendAction(Selector(("openSettings")), to: NSApplication.shared.delegate, from: nil)
            }
            .help(String(localized: "open_settings"))
            ControlBarButton(icon: "chevron.up", active: true) {
                windowController.collapseNow()
            }
            .help(String(localized: "collapse"))
        }
    }

    private var wrappedBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                DragWindowButton(windowController: windowController)
                ControlBarButton(icon: voiceControlEnabled ? "mic.fill" : "mic.slash.fill", active: voiceControlEnabled) {
                    voiceControlEnabled.toggle()
                }
                .help(voiceControlEnabled ? String(localized: "voice_disable") : String(localized: "voice_enable"))
                ControlBarButton(icon: autoScrollPlaying ? "pause.fill" : "play.fill", active: autoScrollPlaying) {
                    autoScrollPlaying.toggle()
                }
                .help(autoScrollPlaying ? String(localized: "scroll_pause") : String(localized: "scroll_auto_short"))
                ControlBarButton(icon: mirrorModeIcon, active: mirrorMode != 0) {
                    mirrorMode = (mirrorMode + 1) % 4
                }
                .help(mirrorModeHelp)
                ControlBarButton(icon: alignmentIcon, active: textAlignment != 0) {
                    textAlignment = (textAlignment + 1) % 4
                }
                .help(alignmentHelp)
            }
            HStack(alignment: .center, spacing: 10) {
                Spacer(minLength: 0)
                ControlBarButton(icon: "gearshape", active: true) {
                    NSApplication.shared.sendAction(Selector(("openSettings")), to: NSApplication.shared.delegate, from: nil)
                }
                .help(String(localized: "open_settings"))
                ControlBarButton(icon: "chevron.up", active: true) {
                    windowController.collapseNow()
                }
                .help(String(localized: "collapse"))
            }
        }
    }

    private var extraCompactBar: some View {
        HStack(alignment: .center, spacing: 8) {
            DragWindowButton(windowController: windowController)
            Menu {
                Button(action: { voiceControlEnabled.toggle() }) {
                    Label(voiceControlEnabled ? String(localized: "voice_off") : String(localized: "voice_on"), systemImage: voiceControlEnabled ? "mic.fill" : "mic.slash.fill")
                }
                Button(action: { autoScrollPlaying.toggle() }) {
                    Label(autoScrollPlaying ? String(localized: "scroll_pause_short") : String(localized: "scroll_auto_short"), systemImage: autoScrollPlaying ? "pause.fill" : "play.fill")
                }
                Divider()
                Menu(String(localized: "mirror_menu")) {
                    Button(String(localized: "mirror_normal")) { mirrorMode = 0 }
                    Button(String(localized: "mirror_h")) { mirrorMode = 1 }
                    Button(String(localized: "mirror_v")) { mirrorMode = 2 }
                    Button(String(localized: "mirror_hv")) { mirrorMode = 3 }
                }
                Menu(String(localized: "alignment_menu")) {
                    Button(String(localized: "align_left")) { textAlignment = 0 }
                    Button(String(localized: "align_center")) { textAlignment = 1 }
                    Button(String(localized: "align_right")) { textAlignment = 2 }
                    Button(String(localized: "align_justified")) { textAlignment = 3 }
                }
                Divider()
                Button(action: { NSApplication.shared.sendAction(Selector(("openSettings")), to: NSApplication.shared.delegate, from: nil) }) {
                    Label(String(localized: "settings"), systemImage: "gearshape")
                }
                Button(action: { windowController.collapseNow() }) {
                    Label(String(localized: "collapse"), systemImage: "chevron.up")
                }
            } label: {
                Image(systemName: "line.3.horizontal.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(buttonColorFromHex(buttonColorHex).opacity(0.9 * buttonOpacity))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help(String(localized: "menu_compact_help"))
            Spacer(minLength: 0)
        }
    }
}
