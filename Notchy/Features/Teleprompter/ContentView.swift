import AppKit
import SwiftUI

/// Padding from the top so text starts below the notch (same reference as the notch strip).
private let notchTopPadding: CGFloat = 32

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

struct ContentView: View {
    @EnvironmentObject var windowController: FloatingWindowController
    @EnvironmentObject var audioMonitor: AudioMonitor
    @EnvironmentObject var scrollController: ScrollController
    @ObservedObject private var scriptStore = ScriptStore.shared

    /// Teleprompter mostra texto puro (body). Edições no prompter atualizam o script como texto puro e limpam RTF.
    private var prompterText: Binding<String> {
        Binding(
            get: { scriptStore.currentScriptBody },
            set: { scriptStore.updateCurrentScriptBody($0) }
        )
    }
    @AppStorage(NotchyKeys.scrollSpeed) private var scrollSpeed: Double = 40
    @AppStorage(NotchyKeys.fontSize) private var fontSize: Double = 16
    @AppStorage(NotchyKeys.textColor) private var textColorHex = "FFFFFF"
    @AppStorage(NotchyKeys.textOpacity) private var textOpacity: Double = 1
    @AppStorage(NotchyKeys.windowOpacity) private var windowOpacity: Double = 1
    @AppStorage(NotchyKeys.buttonOpacity) private var buttonOpacity: Double = 1
    @AppStorage(NotchyKeys.buttonColorHex) private var buttonColorHex = "FFFFFF"
    @AppStorage(NotchyKeys.voiceControlEnabled) private var voiceControlEnabled = true
    @AppStorage(NotchyKeys.autoScrollPlaying) private var autoScrollPlaying = false
    /// 0 = normal, 1 = horizontal, 2 = vertical, 3 = horizontal+vertical (para teleprompter no reflexo do iPad)
    @AppStorage(NotchyKeys.mirrorMode) private var mirrorMode: Int = 0
    /// 0 = esquerda, 1 = centro, 2 = direita, 3 = justificado
    @AppStorage(NotchyKeys.textAlignment) private var textAlignment: Int = 0
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
        case 0: return String(localized: "mirror_help_0")
        case 1: return String(localized: "mirror_help_1")
        case 2: return String(localized: "mirror_help_2")
        case 3: return String(localized: "mirror_help_3")
        default: return String(localized: "mirror_help_default")
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
        case 0: return String(localized: "alignment_help_0")
        case 1: return String(localized: "alignment_help_1")
        case 2: return String(localized: "alignment_help_2")
        case 3: return String(localized: "alignment_help_3")
        default: return String(localized: "alignment_help_default")
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
                Text(String(localized: "notchy_collapsed"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(buttonColorFromHex(buttonColorHex).opacity(0.7 * buttonOpacity))
            }

            if windowController.isExpanded {
                VStack(spacing: 0) {
                    // Padding para o texto começar abaixo do notch (referência da câmera)
                    Color.clear.frame(height: notchTopPadding)
                    TeleprompterTextView(
                        text: prompterText,
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
        .clipShape(NotchBarShape(roundTopCorners: !windowController.isExpanded && !windowController.isCollapseAnimationInProgress))
        .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 2)
        .overlay(alignment: .bottomTrailing) {
            if windowController.isExpanded {
                ResizeHandleView()
            }
        }
        .onAppear {
            windowController.setHasPrompterText(!scriptStore.currentScriptBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            DispatchQueue.main.async {
                scrollController.isSpeakingBinding = Binding(
                    get: {
                        let voiceOn = (UserDefaults.standard.object(forKey: NotchyKeys.voiceControlEnabled) as? Bool) ?? true
                        return voiceOn && audioMonitor.isSpeaking
                    },
                    set: { _ in }
                )
                scrollController.autoScrollPlayingBinding = Binding(
                    get: { UserDefaults.standard.bool(forKey: NotchyKeys.autoScrollPlaying) },
                    set: { UserDefaults.standard.set($0, forKey: NotchyKeys.autoScrollPlaying) }
                )
                // Só pede permissão de microfone quando o controle por voz está ligado (evita prompt a cada abertura).
                if voiceControlEnabled {
                    audioMonitor.start()
                }
            }
        }
        .onChange(of: voiceControlEnabled) { enabled in
            if enabled {
                audioMonitor.start()
            } else {
                audioMonitor.stop()
            }
        }
        .onChange(of: scriptStore.currentScriptBody) { newValue in
            windowController.setHasPrompterText(!newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .onReceive(NotificationCenter.default.publisher(for: .teleprompterDidPaste)) { notification in
            guard let pasted = notification.userInfo?["pastedText"] as? String, !pasted.isEmpty else { return }
            _ = scriptStore.createScript(fromPaste: pasted)
            scrollController.resetScroll()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name(NotchyKeys.preferredMicrophoneDidChangeNotification))) { _ in
            audioMonitor.stop()
            if voiceControlEnabled {
                audioMonitor.start()
            }
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
}
