import AppKit
import SwiftUI

/// Padding from the top so text starts below the notch (same reference as the notch strip).
private let notchTopPadding: CGFloat = 32

/// Horizontal padding for control bar (fixed; script padding is in settings).
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
    @EnvironmentObject var premiumService: PremiumService
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
    @AppStorage(NotchyKeys.notchBackgroundColorHex) private var notchBackgroundColorHex = "000000"
    @AppStorage(NotchyKeys.voiceControlEnabled) private var voiceControlEnabled = true
    @AppStorage(NotchyKeys.autoScrollPlaying) private var autoScrollPlaying = false
    @AppStorage(NotchyKeys.pauseOnHover) private var pauseOnHover = true
    /// 0 = normal, 1 = horizontal, 2 = vertical, 3 = horizontal+vertical (para teleprompter no reflexo do iPad)
    @AppStorage(NotchyKeys.mirrorMode) private var mirrorMode: Int = 0
    /// 0 = esquerda, 1 = centro, 2 = direita, 3 = justificado
    @AppStorage(NotchyKeys.textAlignment) private var textAlignment: Int = 0
    @AppStorage(NotchyKeys.contentPadding) private var contentPadding: Double = 14
    @State private var barWidth: CGFloat = 400
    @State private var controlBarHeight: CGFloat = 36
    /// Congelados no início do resize para evitar a barra alternar 36↔76 e a área do prompter "pular".
    @State private var frozenBarWidth: CGFloat?
    @State private var frozenBarHeight: CGFloat?
    @State private var isHoveringOverText = false
    @State private var showOnboarding = false
    @State private var keyMonitorToken: Any?

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

    /// When premium is inactive or banned, entire prompter is at 2% opacity and non-interactive.
    private var prompterOpacity: Double {
        (premiumService.isPremium && !premiumService.isBanned) ? 1 : 0.02
    }

    private var isBlocked: Bool { !premiumService.isPremium || premiumService.isBanned }

    var body: some View {
        ZStack {
            // Opacidade da janela só no fundo; texto e controles usam suas próprias opacidades.
            // Recolhido: usa cor configurável (Settings) para combinar com o wallpaper no screenshot.
            Group {
                if windowController.isExpanded {
                    Color.black.opacity(effectiveWindowOpacity)
                } else {
                    colorFromHex(notchBackgroundColorHex).opacity(effectiveWindowOpacity)
                }
            }
            .animation(.easeInOut(duration: 0.15), value: windowController.isExpanded)

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
                    .padding(CGFloat(contentPadding))
                    .contentShape(Rectangle())
                    .onHover { isHoveringOverText = $0 }
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
        .opacity(prompterOpacity)
        .allowsHitTesting(!isBlocked)
        .clipShape(NotchBarShape(
            roundTopCorners: !windowController.isExpanded && !windowController.isCollapseAnimationInProgress,
            notchCutoutWidth: !windowController.isExpanded ? windowController.notchCutoutSize()?.width : nil,
            notchCutoutHeight: !windowController.isExpanded ? windowController.notchCutoutSize()?.height : nil
        ))
        .shadow(color: .black.opacity(windowController.isExpanded ? 0.18 : 0), radius: windowController.isExpanded ? 8 : 0, x: 0, y: windowController.isExpanded ? 2 : 0)
        .overlay(alignment: .bottomTrailing) {
            if windowController.isExpanded {
                ResizeHandleView()
            }
        }
        .overlay {
            if premiumService.isBanned && windowController.isExpanded {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.red.opacity(0.9))
                    Text(String(localized: "account_banned"))
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.7))
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
                scrollController.pauseWhenHoveringBinding = Binding(
                    get: { pauseOnHover && isHoveringOverText },
                    set: { _ in }
                )
                if !UserDefaults.standard.bool(forKey: NotchyKeys.onboardingCompleted) {
                    showOnboarding = true
                }
                // Atalhos de teclado (Space = play/pause, ↑/↓ = passo) quando a janela do teleprompter é a key window.
                let ourWindow = windowController.window
                keyMonitorToken = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak scrollController] event in
                    guard event.window === ourWindow else { return event }
                    switch event.keyCode {
                    case 49: // Space
                        let current = UserDefaults.standard.bool(forKey: NotchyKeys.autoScrollPlaying)
                        UserDefaults.standard.set(!current, forKey: NotchyKeys.autoScrollPlaying)
                        return nil
                    case 126: // Up
                        if let sc = scrollController {
                            sc.scrollOffset = max(0, sc.scrollOffset - ScrollController.keyboardScrollStep)
                        }
                        return nil
                    case 125: // Down
                        scrollController?.scrollOffset += ScrollController.keyboardScrollStep
                        return nil
                    default:
                        return event
                    }
                }
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
        .clipShape(NotchBarShape(
            roundTopCorners: !windowController.isExpanded && !windowController.isCollapseAnimationInProgress,
            notchCutoutWidth: !windowController.isExpanded ? windowController.notchCutoutSize()?.width : nil,
            notchCutoutHeight: !windowController.isExpanded ? windowController.notchCutoutSize()?.height : nil
        ))
        .onDisappear {
            if let token = keyMonitorToken {
                NSEvent.removeMonitor(token)
                keyMonitorToken = nil
            }
            DispatchQueue.main.async {
                audioMonitor.stop()
                scrollController.isSpeakingBinding = nil
                scrollController.autoScrollPlayingBinding = nil
                scrollController.pauseWhenHoveringBinding = nil
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView {
                showOnboarding = false
                UserDefaults.standard.set(true, forKey: NotchyKeys.onboardingCompleted)
            }
        }
    }
}

// MARK: - Onboarding

private struct OnboardingView: View {
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "rectangle.topthird.inset.filled")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(String(localized: "onboarding_title"))
                .font(.title2.weight(.semibold))
            Text(String(localized: "onboarding_trial"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            VStack(alignment: .leading, spacing: 12) {
                OnboardingRow(icon: "doc.on.clipboard", text: String(localized: "onboarding_paste"))
                OnboardingRow(icon: "mic.fill", text: String(localized: "onboarding_speak"))
                OnboardingRow(icon: "chevron.up", text: String(localized: "onboarding_collapse"))
            }
            .padding(.vertical, 8)
            Button(String(localized: "onboarding_got_it")) {
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .padding(32)
        .frame(width: 360)
    }
}

private struct OnboardingRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .center)
            Text(text)
                .font(.body)
        }
    }
}
