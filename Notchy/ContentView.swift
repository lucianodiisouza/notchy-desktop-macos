import AppKit
import SwiftUI

/// Padding from the top so text starts below the notch (same reference as the notch strip).
private let notchTopPadding: CGFloat = 32

/// Hex to Color for button/icon tint (used by bar controls).
fileprivate func buttonColorFromHex(_ hex: String) -> Color {
    let s = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: s).scanHexInt64(&int)
    let r = Double((int >> 16) & 0xFF) / 255
    let g = Double((int >> 8) & 0xFF) / 255
    let b = Double(int & 0xFF) / 255
    return Color(red: r, green: g, blue: b)
}

/// Horizontal padding so text isn't flush to the edges.
private let sidePadding: CGFloat = 14

private struct ControlBarWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 400
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct ControlBarHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 36
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// Only the bottom edge is rounded so the bar looks docked into the top of the screen.
/// Radius scales with window size so small windows don't lose rounding or clip icons.
private struct NotchBarShape: Shape {
    private static let maxCornerRadius: CGFloat = 10
    private static let minCornerRadius: CGFloat = 4

    func path(in rect: CGRect) -> Path {
        let r = effectiveCornerRadius(for: rect)
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r), radius: r, startAngle: Angle(degrees: 0), endAngle: Angle(degrees: 90), clockwise: false)
        path.addLine(to: CGPoint(x: r, y: rect.maxY))
        path.addArc(center: CGPoint(x: r, y: rect.maxY - r), radius: r, startAngle: Angle(degrees: 90), endAngle: Angle(degrees: 180), clockwise: false)
        path.closeSubpath()
        return path
    }

    /// Keeps corner radius proportional to window size so content isn't clipped when small.
    /// Never exceeds half width or full height so the two bottom corners don't overlap.
    private func effectiveCornerRadius(for rect: CGRect) -> CGFloat {
        let smallSide = min(rect.width, rect.height)
        let proportional = smallSide * 0.06
        let capped = min(Self.maxCornerRadius, max(Self.minCornerRadius, proportional))
        let maxValid = min(rect.width / 2, rect.height)
        return min(capped, max(1, maxValid - 1))
    }
}

/// Two diagonal lines in the corner for resize grip (Mac-style).
private struct ResizeGripShape: Shape {
    func path(in rect: CGRect) -> Path {
        let margin: CGFloat = 6
        let spacing: CGFloat = 4
        var path = Path()
        // Line 1: from bottom-left to top-right of grip area
        path.move(to: CGPoint(x: rect.minX + margin, y: rect.maxY - margin))
        path.addLine(to: CGPoint(x: rect.maxX - margin, y: rect.minY + margin))
        // Line 2: parallel diagonal, offset
        path.move(to: CGPoint(x: rect.minX + margin + spacing, y: rect.maxY - margin))
        path.addLine(to: CGPoint(x: rect.maxX - margin, y: rect.minY + margin + spacing))
        return path
    }
}

/// Botão da barra de controles (mic, play, recolher) — tamanho fixo para alinhamento.
private struct ControlBarButton: View {
    let icon: String
    let active: Bool
    let action: () -> Void
    @AppStorage("buttonColorHex") private var buttonColorHex = "FFFFFF"
    @AppStorage("buttonOpacity") private var buttonOpacity: Double = 1

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

/// Resize via AppKit (coordenadas de tela) para não ter o mesmo tremor do DragGesture do SwiftUI
/// quando a janela muda de tamanho e o layout da view acompanha.
private final class ResizeHandleMouseView: NSView {
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
        guard let window = window, windowController != nil else { return }
        dragStartFrame = window.frame
        dragStartLocation = NSEvent.mouseLocation
    }

    override func mouseDragged(with event: NSEvent) {
        guard windowController != nil, let window = window else { return }
        let current = NSEvent.mouseLocation
        let deltaX = current.x - dragStartLocation.x
        let deltaY = dragStartLocation.y - current.y // y sobe na tela; arrastar pra baixo = mais altura
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

private struct ResizeHandleRepresentable: NSViewRepresentable {
    let windowController: FloatingWindowController

    func makeNSView(context: Context) -> ResizeHandleMouseView {
        let v = ResizeHandleMouseView()
        v.windowController = windowController
        return v
    }

    func updateNSView(_ nsView: ResizeHandleMouseView, context: Context) {
        nsView.windowController = windowController
    }
}

/// Resize handle: desenho em SwiftUI, interação via AppKit (evita salto ao redimensionar).
private struct ResizeHandleView: View {
    @EnvironmentObject var windowController: FloatingWindowController
    @AppStorage("buttonOpacity") private var buttonOpacity: Double = 1
    @AppStorage("buttonColorHex") private var buttonColorHex = "FFFFFF"

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

/// Arrasto via AppKit com coordenadas de tela (NSEvent.mouseLocation) para evitar tremor:
/// no SwiftUI, ao mover a janela a view acompanha e o DragGesture "reseta" a tradução, causando vai-e-volta.
private final class DragHandleMouseView: NSView {
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
        UserDefaults.standard.set(false, forKey: "windowPinnedToNotch")
    }

    override func mouseDragged(with event: NSEvent) {
        guard let _ = window,
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

private struct DragHandleRepresentable: NSViewRepresentable {
    let windowController: FloatingWindowController
    var onMouseEnter: (() -> Void)? = nil
    var onMouseExit: (() -> Void)? = nil

    func makeNSView(context: Context) -> DragHandleMouseView {
        let v = DragHandleMouseView()
        v.windowController = windowController
        v.onMouseEnter = onMouseEnter
        v.onMouseExit = onMouseExit
        return v
    }

    func updateNSView(_ nsView: DragHandleMouseView, context: Context) {
        nsView.windowController = windowController
        nsView.onMouseEnter = onMouseEnter
        nsView.onMouseExit = onMouseExit
    }
}

/// Botão de arrastar: segurar e arrastar para mover a janela. Usa AppKit (coordenadas de tela) para evitar tremor.
private struct DragWindowButton: View {
    let windowController: FloatingWindowController
    @AppStorage("buttonColorHex") private var buttonColorHex = "FFFFFF"
    @AppStorage("buttonOpacity") private var buttonOpacity: Double = 1

    var body: some View {
        ZStack {
            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                .font(.system(size: 12))
                .foregroundColor(buttonColorFromHex(buttonColorHex).opacity(0.7 * buttonOpacity))
            DragHandleRepresentable(windowController: windowController)
        }
        .frame(width: 28, height: 28)
        .contentShape(Rectangle())
        .help("Arrastar para mover. Duplo clique para fixar de volta no notch.")
    }
}

/// Barra de controles: full (todos os botões), compact (menu + gear + chevron), wrapped (duas linhas) ou extra-compact (só arrastar + menu).
private struct ControlBarView: View {
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
    @AppStorage("buttonColorHex") private var buttonColorHex = "FFFFFF"
    @AppStorage("buttonOpacity") private var buttonOpacity: Double = 1

    /// Abaixo disso: só arrastar + menu (extra compacto).
    private var useExtraCompact: Bool { barWidth < extraCompactThreshold }
    /// Entre extraCompact e compact: duas linhas de botões (flex wrap) para não cortar.
    private var useWrapped: Bool { barWidth < compactThreshold && barWidth >= extraCompactThreshold }
    /// Acima de compactThreshold: uma linha com todos os ícones.

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

    private var barHeight: CGFloat { useWrapped ? 76 : 36 }

    private var fullBar: some View {
        HStack(alignment: .center, spacing: 12) {
            DragWindowButton(windowController: windowController)
            ControlBarButton(icon: voiceControlEnabled ? "mic.fill" : "mic.slash.fill", active: voiceControlEnabled) {
                voiceControlEnabled.toggle()
            }
            .help(voiceControlEnabled ? "Desativar scroll por voz" : "Ativar scroll por voz")
            ControlBarButton(icon: autoScrollPlaying ? "pause.fill" : "play.fill", active: autoScrollPlaying) {
                autoScrollPlaying.toggle()
            }
            .help(autoScrollPlaying ? "Pausar scroll automático" : "Scroll automático (velocidade nas configurações)")
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
            .help("Abrir configurações")
            ControlBarButton(icon: "chevron.up", active: true) {
                windowController.collapseNow()
            }
            .help("Recolher")
        }
    }

    /// Duas linhas (flex wrap) para caber em janelas estreitas sem cortar botões.
    private var wrappedBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                DragWindowButton(windowController: windowController)
                ControlBarButton(icon: voiceControlEnabled ? "mic.fill" : "mic.slash.fill", active: voiceControlEnabled) {
                    voiceControlEnabled.toggle()
                }
                .help(voiceControlEnabled ? "Desativar scroll por voz" : "Ativar scroll por voz")
                ControlBarButton(icon: autoScrollPlaying ? "pause.fill" : "play.fill", active: autoScrollPlaying) {
                    autoScrollPlaying.toggle()
                }
                .help(autoScrollPlaying ? "Pausar scroll automático" : "Scroll automático")
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
                .help("Abrir configurações")
                ControlBarButton(icon: "chevron.up", active: true) {
                    windowController.collapseNow()
                }
                .help("Recolher")
            }
        }
    }

    private var compactBar: some View {
        HStack(alignment: .center, spacing: 12) {
            DragWindowButton(windowController: windowController)
            Menu {
                Button(action: { voiceControlEnabled.toggle() }) {
                    Label(voiceControlEnabled ? "Desativar voz" : "Ativar voz", systemImage: voiceControlEnabled ? "mic.fill" : "mic.slash.fill")
                }
                Button(action: { autoScrollPlaying.toggle() }) {
                    Label(autoScrollPlaying ? "Pausar scroll" : "Scroll automático", systemImage: autoScrollPlaying ? "pause.fill" : "play.fill")
                }
                Divider()
                Menu("Espelho") {
                    Button("Normal") { mirrorMode = 0 }
                    Button("Horizontal") { mirrorMode = 1 }
                    Button("Vertical") { mirrorMode = 2 }
                    Button("Horizontal + Vertical") { mirrorMode = 3 }
                }
                Menu("Alinhamento") {
                    Button("Esquerda") { textAlignment = 0 }
                    Button("Centro") { textAlignment = 1 }
                    Button("Direita") { textAlignment = 2 }
                    Button("Justificado") { textAlignment = 3 }
                }
                Divider()
                Button(action: { NSApplication.shared.sendAction(Selector(("openSettings")), to: NSApplication.shared.delegate, from: nil) }) {
                    Label("Configurações", systemImage: "gearshape")
                }
                Button(action: { windowController.collapseNow() }) {
                    Label("Recolher", systemImage: "chevron.up")
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(buttonColorFromHex(buttonColorHex).opacity(0.9 * buttonOpacity))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Menu de controles (janela estreita)")
            Spacer(minLength: 0)
            ControlBarButton(icon: "gearshape", active: true) {
                NSApplication.shared.sendAction(Selector(("openSettings")), to: NSApplication.shared.delegate, from: nil)
            }
            .help("Abrir configurações")
            ControlBarButton(icon: "chevron.up", active: true) {
                windowController.collapseNow()
            }
            .help("Recolher")
        }
    }

    /// Janela na largura mínima (tipo notch): só arrastar + um menu com todas as ações.
    private var extraCompactBar: some View {
        HStack(alignment: .center, spacing: 8) {
            DragWindowButton(windowController: windowController)
            Menu {
                Button(action: { voiceControlEnabled.toggle() }) {
                    Label(voiceControlEnabled ? "Desativar voz" : "Ativar voz", systemImage: voiceControlEnabled ? "mic.fill" : "mic.slash.fill")
                }
                Button(action: { autoScrollPlaying.toggle() }) {
                    Label(autoScrollPlaying ? "Pausar scroll" : "Scroll automático", systemImage: autoScrollPlaying ? "pause.fill" : "play.fill")
                }
                Divider()
                Menu("Espelho") {
                    Button("Normal") { mirrorMode = 0 }
                    Button("Horizontal") { mirrorMode = 1 }
                    Button("Vertical") { mirrorMode = 2 }
                    Button("Horizontal + Vertical") { mirrorMode = 3 }
                }
                Menu("Alinhamento") {
                    Button("Esquerda") { textAlignment = 0 }
                    Button("Centro") { textAlignment = 1 }
                    Button("Direita") { textAlignment = 2 }
                    Button("Justificado") { textAlignment = 3 }
                }
                Divider()
                Button(action: { NSApplication.shared.sendAction(Selector(("openSettings")), to: NSApplication.shared.delegate, from: nil) }) {
                    Label("Configurações", systemImage: "gearshape")
                }
                Button(action: { windowController.collapseNow() }) {
                    Label("Recolher", systemImage: "chevron.up")
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
            .help("Menu (janela na largura mínima)")
            Spacer(minLength: 0)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var windowController: FloatingWindowController
    @EnvironmentObject var audioMonitor: AudioMonitor
    @EnvironmentObject var scrollController: ScrollController

    @AppStorage("prompterText") private var prompterText = ""
    @AppStorage("scrollSpeed") private var scrollSpeed: Double = 40
    @AppStorage("fontSize") private var fontSize: Double = 16
    @AppStorage("textColor") private var textColorHex = "FFFFFF"
    @AppStorage("textOpacity") private var textOpacity: Double = 1
    @AppStorage("windowOpacity") private var windowOpacity: Double = 1
    @AppStorage("buttonOpacity") private var buttonOpacity: Double = 1
    @AppStorage("buttonColorHex") private var buttonColorHex = "FFFFFF"
    @AppStorage("voiceControlEnabled") private var voiceControlEnabled = true
    @AppStorage("autoScrollPlaying") private var autoScrollPlaying = false
    /// 0 = normal, 1 = horizontal, 2 = vertical, 3 = horizontal+vertical (para teleprompter no reflexo do iPad)
    @AppStorage("mirrorMode") private var mirrorMode: Int = 0
    /// 0 = esquerda, 1 = centro, 2 = direita, 3 = justificado
    @AppStorage("textAlignment") private var textAlignment: Int = 0
    @State private var barWidth: CGFloat = 400
    @State private var controlBarHeight: CGFloat = 36
    /// Congelados no início do resize para evitar a barra alternar 36↔76 e a área do prompter "pular".
    @State private var frozenBarWidth: CGFloat?
    @State private var frozenBarHeight: CGFloat?

    /// Opacidade mínima para o fundo garante que a janela continue recebendo cliques quando o usuário escolhe 0%.
    private var effectiveWindowOpacity: Double {
        max(windowOpacity, 0.004)
    }

    private var mirrorScaleX: CGFloat { mirrorMode == 1 || mirrorMode == 3 ? -1 : 1 }
    private var mirrorScaleY: CGFloat { mirrorMode == 2 || mirrorMode == 3 ? -1 : 1 }
    private var mirrorModeIcon: String {
        switch mirrorMode {
        case 1: return "arrow.left.and.right"
        case 2: return "arrow.up.and.down"
        case 3: return "arrow.up.left.and.arrow.down.right"
        default: return "rectangle.portrait.rotate"
        }
    }
    private var mirrorModeHelp: String {
        switch mirrorMode {
        case 0: return "Espelhar para teleprompter (próximo: horizontal)"
        case 1: return "Espelho horizontal (próximo: vertical)"
        case 2: return "Espelho vertical (próximo: ambos)"
        case 3: return "Espelho H+V (próximo: normal)"
        default: return "Espelhar para teleprompter"
        }
    }

    private var alignmentIcon: String {
        switch textAlignment {
        case 1: return "text.aligncenter"
        case 2: return "text.alignright"
        case 3: return "text.justify"
        default: return "text.alignleft"
        }
    }
    private var alignmentHelp: String {
        switch textAlignment {
        case 0: return "Alinhamento: esquerda (próximo: centro)"
        case 1: return "Alinhamento: centro (próximo: direita)"
        case 2: return "Alinhamento: direita (próximo: justificado)"
        case 3: return "Alinhamento: justificado (próximo: esquerda)"
        default: return "Alinhamento do texto"
        }
    }

    /// Largura abaixo da qual a barra quebra em duas linhas (flex wrap) em vez de uma só.
    private let controlBarCompactThreshold: CGFloat = 380
    /// Largura abaixo da qual a barra mostra só arrastar + um menu (modo extra compacto).
    private let controlBarExtraCompactThreshold: CGFloat = 140

    /// Durante o resize, usa dimensões congeladas para não alternar 36↔76 e evitar o pulo da área do prompter.
    private var effectiveBarWidth: CGFloat {
        frozenBarWidth ?? barWidth
    }
    private var effectiveBarHeight: CGFloat {
        frozenBarHeight ?? controlBarHeight
    }

    var body: some View {
        ZStack {
            // Opacidade da janela só no fundo; texto e controles usam suas próprias opacidades.
            // Usamos effectiveWindowOpacity para que, mesmo em 0%, a janela ainda seja clicável (macOS ignora hit em views totalmente transparentes).
            Color.black.opacity(effectiveWindowOpacity)

            // Recolhido: indicador mínimo para saber onde está o app (hover para expandir)
            if !windowController.isExpanded {
                Text("Notchy ▼")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(buttonColorFromHex(buttonColorHex).opacity(0.7 * buttonOpacity))
            }

            if windowController.isExpanded {
                VStack(spacing: 0) {
                    // Padding para o texto começar abaixo do notch (referência da câmera)
                    Color.clear.frame(height: notchTopPadding)
                    TeleprompterTextView(
                        text: $prompterText,
                        scrollOffset: Binding(
                            get: { scrollController.scrollOffset },
                            set: { scrollController.scrollOffset = $0 }
                        ),
                        fontSize: fontSize,
                        textColor: colorFromHex(textColorHex),
                        textOpacity: textOpacity,
                        alignmentMode: textAlignment
                    )
                    .scaleEffect(x: mirrorScaleX, y: mirrorScaleY)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, sidePadding)
                    // Barra de controles: fundo arrastável; botões ou menu quando estreito
                    ControlBarView(
                            barWidth: effectiveBarWidth,
                            compactThreshold: controlBarCompactThreshold,
                            extraCompactThreshold: controlBarExtraCompactThreshold,
                            voiceControlEnabled: $voiceControlEnabled,
                            autoScrollPlaying: $autoScrollPlaying,
                            mirrorMode: $mirrorMode,
                            textAlignment: $textAlignment,
                            mirrorModeIcon: mirrorModeIcon,
                            mirrorModeHelp: mirrorModeHelp,
                            alignmentIcon: alignmentIcon,
                            alignmentHelp: alignmentHelp,
                            windowController: windowController
                        )
                    .frame(height: effectiveBarHeight)
                    .padding(.horizontal, sidePadding)
                    .padding(.trailing, 36)
                    .padding(.vertical, 8)
                    .background(GeometryReader { g in
                        // g.size já é a área da barra (view com padding aplicado)
                        let w = max(0, g.size.width)
                        let useWrapped = w < controlBarCompactThreshold && w >= controlBarExtraCompactThreshold
                        Color.clear
                            .preference(key: ControlBarWidthKey.self, value: w)
                            .preference(key: ControlBarHeightKey.self, value: useWrapped ? 76 : 36)
                    })
                    .onPreferenceChange(ControlBarWidthKey.self) { barWidth = $0 }
                    .onPreferenceChange(ControlBarHeightKey.self) { controlBarHeight = $0 }
                    .onChange(of: windowController.isWindowResizing) { resizing in
                        if resizing {
                            frozenBarWidth = barWidth
                            frozenBarHeight = controlBarHeight
                        } else {
                            frozenBarWidth = nil
                            frozenBarHeight = nil
                        }
                    }
                }
            }
        }
        .clipShape(NotchBarShape())
        .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 2)
        .overlay(alignment: .bottomTrailing) {
            if windowController.isExpanded {
                ResizeHandleView()
            }
        }
        .onAppear {
            windowController.setHasPrompterText(!prompterText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            DispatchQueue.main.async {
                scrollController.isSpeakingBinding = Binding(
                    get: {
                        let voiceOn = (UserDefaults.standard.object(forKey: "voiceControlEnabled") as? Bool) ?? true
                        return voiceOn && audioMonitor.isSpeaking
                    },
                    set: { _ in }
                )
                scrollController.autoScrollPlayingBinding = Binding(
                    get: { UserDefaults.standard.bool(forKey: "autoScrollPlaying") },
                    set: { UserDefaults.standard.set($0, forKey: "autoScrollPlaying") }
                )
                audioMonitor.start()
            }
        }
        .onChange(of: prompterText) { newValue in
            windowController.setHasPrompterText(!newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .overlay(WindowAccessor(windowController: windowController))
        .overlay(alignment: .top) {
            // Qualquer ponto da faixa do notch (que não seja botão/área de texto) serve para arrastar a janela.
            if windowController.isExpanded {
                DragHandleRepresentable(
                    windowController: windowController,
                    onMouseEnter: { windowController.setExpanded(true) },
                    onMouseExit: { windowController.setExpanded(false) }
                )
                .frame(height: notchTopPadding)
                .frame(maxWidth: .infinity)
            }
        }
        .onDisappear {
            DispatchQueue.main.async {
                audioMonitor.stop()
                scrollController.isSpeakingBinding = nil
                scrollController.autoScrollPlayingBinding = nil
            }
        }
    }

    private func colorFromHex(_ hex: String) -> Color {
        let s = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: s).scanHexInt64(&int)
        let a = Double((int >> 24) & 0xFF) / 255
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        return Color(red: r, green: g, blue: b, opacity: a > 0 ? a : 1)
    }
}
