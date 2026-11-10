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
    /// Not observed: the offset changes every frame while scrolling, and the text view follows it on its own. Observing
    /// it here rebuilt this whole view (control bar, shapes, colors) 60 times a second.
    private var scrollController: ScrollController { NotchyState.shared.scrollController }
    @EnvironmentObject var speechFollower: SpeechFollower
    @ObservedObject private var scriptStore = ScriptStore.shared

    /// The prompter shows the script as plain text. Typing here saves plain text and drops the editor's formatting.
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
    @AppStorage(NotchyKeys.collapsedBarLabel) private var collapsedBarLabel = ""
    @AppStorage(NotchyKeys.voiceControlEnabled) private var voiceControlEnabled = true
    @AppStorage(NotchyKeys.voiceMode) private var voiceModeRaw = VoiceMode.level.rawValue
    @AppStorage(NotchyKeys.highlightSpokenText) private var highlightSpokenText = true
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
    /// A reference, not @State, so the scroll timer reads the live value from its closure.
    @State private var hoverState = HoverState()
    @State private var showOnboarding = false

    private var isFollowingWords: Bool {
        voiceControlEnabled && voiceModeRaw == VoiceMode.follow.rawValue
    }

    private var listeningIcon: String {
        guard voiceControlEnabled else { return "mic.slash.fill" }
        return isFollowingWords ? "waveform" : "mic.fill"
    }

    private var listeningHelp: String {
        guard voiceControlEnabled else { return String(localized: "voice_enable") }
        switch speechFollower.status {
        case .denied where isFollowingWords: return String(localized: "follow_status_denied")
        case .unsupportedLanguage(let name) where isFollowingWords:
            return String(format: String(localized: "follow_status_unsupported"), name)
        case .downloadingLanguage(let name) where isFollowingWords:
            return String(format: String(localized: "follow_status_downloading"), name)
        default:
            return isFollowingWords ? String(localized: "follow_listening_help") : String(localized: "voice_disable")
        }
    }

    /// Texto na barra recolhida: customizado em Settings ou "Notchy ▼".
    private var collapsedBarDisplayText: String {
        let custom = collapsedBarLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        if custom.isEmpty { return String(localized: "notchy_collapsed") }
        return custom + " ▼"
    }
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

            // Recolhido: indicador mínimo (texto customizável em Settings; hover para expandir)
            if !windowController.isExpanded {
                Text(collapsedBarDisplayText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(buttonColorFromHex(buttonColorHex).opacity(0.7 * buttonOpacity))
            }

            if windowController.isExpanded {
                VStack(spacing: 0) {
                    // Padding para o texto começar abaixo do notch (referência da câmera)
                    Color.clear.frame(height: notchTopPadding)
                    TeleprompterTextView(
                        text: prompterText,
                        scrollController: scrollController,
                        speechFollower: speechFollower,
                        fontSize: fontSize,
                        textColor: colorFromHex(textColorHex),
                        textOpacity: textOpacity,
                        alignmentMode: textAlignment,
                        showsReadingPosition: isFollowingWords && highlightSpokenText
                    )
                    .scaleEffect(x: mirrorScaleX, y: mirrorScaleY)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(CGFloat(contentPadding))
                    .contentShape(Rectangle())
                    .onHover { hoverState.isHovering = $0 }
                    // Barra de controles: fundo arrastável; botões ou menu quando estreito
                    ControlBarView(
                            barWidth: effectiveBarWidth,
                            compactThreshold: controlBarCompactThreshold,
                            extraCompactThreshold: controlBarExtraCompactThreshold,
                            voiceControlEnabled: $voiceControlEnabled,
                            listeningIcon: listeningIcon,
                            listeningHelp: listeningHelp,
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
                    .onChange(of: windowController.isWindowResizing) { _, resizing in
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
        .onAppear {
            windowController.setHasPrompterText(!scriptStore.currentScriptBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            DispatchQueue.main.async {
                let hover = hoverState
                scrollController.isPaused = {
                    let pauseOnHover = UserDefaults.standard.object(forKey: NotchyKeys.pauseOnHover) as? Bool ?? true
                    return pauseOnHover && hover.isHovering
                }
                if !UserDefaults.standard.bool(forKey: NotchyKeys.onboardingCompleted) {
                    showOnboarding = true
                }
                // Space = play/pause, ↑/↓ = step, while the prompter window is key and you are not typing in the text.
                let ourWindow = windowController.window
                let scrollController = self.scrollController
                keyMonitorToken = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    guard event.window === ourWindow, !(ourWindow?.firstResponder is NSTextView) else { return event }
                    switch event.keyCode {
                    case 126 where event.modifierFlags.contains(.shift), 125 where event.modifierFlags.contains(.shift): // ⇧↑ / ⇧↓: faster / slower
                        let key = NotchyKeys.scrollSpeed
                        let speed = UserDefaults.standard.object(forKey: key) as? Double ?? 40
                        UserDefaults.standard.set(event.keyCode == 126 ? min(120, speed + 10) : max(10, speed - 10), forKey: key)
                        return nil
                    case 49: // Space
                        let current = UserDefaults.standard.bool(forKey: NotchyKeys.autoScrollPlaying)
                        UserDefaults.standard.set(!current, forKey: NotchyKeys.autoScrollPlaying)
                        return nil
                    case 126: // Up
                        scrollController.scrollOffset = max(0, scrollController.scrollOffset - ScrollController.keyboardScrollStep)
                        return nil
                    case 125: // Down
                        scrollController.scrollOffset += ScrollController.keyboardScrollStep
                        return nil
                    default:
                        return event
                    }
                }
                NotchyState.shared.prompterDidAppear()
            }
        }
        .onChange(of: scriptStore.currentScriptBody) { _, newValue in
            windowController.setHasPrompterText(!newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .onReceive(NotificationCenter.default.publisher(for: .teleprompterDidPaste)) { notification in
            guard let pasted = notification.userInfo?["pastedText"] as? String, !pasted.isEmpty else { return }
            scriptStore.createScript(fromPaste: pasted)
            NotchyState.shared.resetReading()
        }
        .overlay(WindowAccessor(windowController: windowController))
        .overlay(alignment: .top) {
            // Qualquer ponto da faixa do notch (que não seja botão/área de texto) serve para arrastar a janela.
            if windowController.isExpanded {
                // Only drag/drop and expand on enter here. Do not set onMouseExit: collapse must happen
                // only when the mouse leaves the entire window (handled by WindowAccessor), not when
                // moving from the strip to buttons/content.
                DragHandleRepresentable(
                    windowController: windowController,
                    onMouseEnter: { windowController.setExpanded(true) },
                    onMouseExit: nil
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
                scrollController.isPaused = { false }
                NotchyState.shared.prompterDidDisappear()
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

/// Whether the pointer is over the text, shared with the scroll timer.
private final class HoverState {
    var isHovering = false
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
            Text(String(localized: "onboarding_subtitle"))
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
