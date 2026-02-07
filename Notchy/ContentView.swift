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

/// Only the bottom edge is rounded so the bar looks docked into the top of the screen.
private struct NotchBarShape: Shape {
    private let cornerRadius: CGFloat = 10

    func path(in rect: CGRect) -> Path {
        let r = cornerRadius
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

/// Resize handle view: drag to resize window (updates UserDefaults and refreshes frame).
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

private struct ResizeHandleView: View {
    @EnvironmentObject var windowController: FloatingWindowController
    @AppStorage("windowWidth") private var windowWidth: Double = 0
    @AppStorage("windowHeight") private var windowHeight: Double = 320
    @AppStorage("buttonOpacity") private var buttonOpacity: Double = 1
    @AppStorage("buttonColorHex") private var buttonColorHex = "FFFFFF"

    private let minWidth: Double = 200
    private let maxWidth: Double = 1200
    private let minHeight: Double = 200
    private let maxHeight: Double = 600
    @State private var dragStartWidth: Double = 0
    @State private var dragStartHeight: Double = 0
    @State private var dragStarted = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.clear
            ResizeGripShape()
                .stroke(buttonColorFromHex(buttonColorHex).opacity(0.5 * buttonOpacity), lineWidth: 1.5)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
                .frame(width: 28, height: 28)
                .padding(4)
                .onHover { inside in
                    if inside { NSCursor.resizeUpDown.push() }
                    else { NSCursor.pop() }
                }
                .highPriorityGesture(
                    DragGesture(minimumDistance: 2)
                        .onChanged { value in
                            if !dragStarted {
                                dragStartHeight = windowHeight
                                // Em modo Auto (width 0), usar a largura atual da janela como base para o arrasto
                                let currentW = windowController.currentWindowFrame()?.width
                                dragStartWidth = windowWidth > 0 ? windowWidth : Double(currentW ?? minWidth)
                                dragStarted = true
                            }
                            let newH = max(minHeight, min(maxHeight, dragStartHeight + value.translation.height))
                            let newW = max(minWidth, min(maxWidth, dragStartWidth + value.translation.width))
                            windowController.setTemporaryResize(width: newW, height: newH)
                        }
                        .onEnded { value in
                            if dragStarted {
                                let newH = max(minHeight, min(maxHeight, dragStartHeight + value.translation.height))
                                let newW = max(minWidth, min(maxWidth, dragStartWidth + value.translation.width))
                                windowHeight = newH
                                windowWidth = newW
                                windowController.setTemporaryResize(width: nil, height: nil)
                            }
                            dragStarted = false
                        }
                )
        }
        .frame(width: 32, height: 32)
    }
}

/// Arrasto via AppKit com coordenadas de tela (NSEvent.mouseLocation) para evitar tremor:
/// no SwiftUI, ao mover a janela a view acompanha e o DragGesture "reseta" a tradução, causando vai-e-volta.
private final class DragHandleMouseView: NSView {
    weak var windowController: FloatingWindowController?
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
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.pop()
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

    func makeNSView(context: Context) -> DragHandleMouseView {
        let v = DragHandleMouseView()
        v.windowController = windowController
        return v
    }

    func updateNSView(_ nsView: DragHandleMouseView, context: Context) {
        nsView.windowController = windowController
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

    /// Opacidade mínima para o fundo garante que a janela continue recebendo cliques quando o usuário escolhe 0%.
    private var effectiveWindowOpacity: Double {
        max(windowOpacity, 0.004)
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
                        textOpacity: textOpacity
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, sidePadding)
                    // Barra de controles: mic, play, collapse, arrastar (ícones) — altura fixa e alinhados
                    HStack(alignment: .center, spacing: 12) {
                        DragWindowButton(windowController: windowController)
                        ControlBarButton(icon: voiceControlEnabled ? "mic.fill" : "mic.slash.fill", active: voiceControlEnabled) {
                            voiceControlEnabled.toggle()
                        }
                        .help(voiceControlEnabled ? "Desativar scroll por voz" : "Ativar scroll por voz")
                        ControlBarButton(icon: autoScrollPlaying ? "pause.fill" : "play.fill", active: autoScrollPlaying) {
                            autoScrollPlaying.toggle()
                        }
                        .help(autoScrollPlaying ? "Pausar scroll automático" : "Scroll automático (velocidade em Settings)")
                        Spacer(minLength: 0)
                        ControlBarButton(icon: "chevron.up", active: true) {
                            windowController.collapseNow()
                        }
                        .help("Recolher")
                    }
                    .frame(height: 36)
                    .padding(.horizontal, sidePadding)
                    .padding(.trailing, 36)
                    .padding(.vertical, 8)
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
