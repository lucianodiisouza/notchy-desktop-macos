import AppKit
import Speech
import SwiftUI

// One view per page of the settings window. Every control writes straight to UserDefaults; the prompter reads the
// same keys, so a change shows up on it right away.

// MARK: - Text

struct TextSettingsPage: View {
    @AppStorage(NotchyKeys.fontSize) private var fontSize: Double = 16
    @AppStorage(NotchyKeys.textColor) private var textColorHex = "FFFFFF"
    @AppStorage(NotchyKeys.textOpacity) private var textOpacity: Double = 1
    @AppStorage(NotchyKeys.textAlignment) private var textAlignment: Int = 0
    @AppStorage(NotchyKeys.mirrorMode) private var mirrorMode: Int = 0
    @AppStorage(NotchyKeys.contentPadding) private var contentPadding: Double = 14

    var body: some View {
        SettingsPage {
            SettingsSectionTitle(title: "settings_page_text", subtitle: "settings_text_subtitle")
            PrompterPreview(
                fontSize: fontSize, color: colorFromHex(textColorHex), opacity: textOpacity,
                alignment: textAlignment, mirror: mirrorMode, padding: contentPadding)
            SettingsGroup {
                SettingsSliderRow(
                    symbol: "textformat.size", color: SettingsPageID.text.color, title: "label_font_size",
                    value: $fontSize, range: 10...48, step: 1, format: { "\(Int($0)) pt" })
                SettingsColorRow(
                    symbol: "paintpalette.fill", color: Color(hex: "#EC4899"), title: "picker_text_color",
                    selection: Binding(get: { colorFromHex(textColorHex) }, set: { textColorHex = hexFromColor($0) }))
                SettingsSliderRow(
                    symbol: "circle.lefthalf.filled", color: Color(hex: "#64748B"), title: "label_text_opacity",
                    subtitle: "text_opacity_help",
                    value: $textOpacity, range: 0.1...1, step: 0.05, format: { "\(Int(($0 * 100).rounded()))%" })
            }
            SettingsGroup {
                SettingsPickerRow(
                    symbol: "text.alignleft", color: Color(hex: "#0EA5E9"), title: "alignment_menu",
                    selection: $textAlignment
                ) {
                    Text(String(localized: "align_left")).tag(0)
                    Text(String(localized: "align_center")).tag(1)
                    Text(String(localized: "align_right")).tag(2)
                    Text(String(localized: "align_justified")).tag(3)
                }
                SettingsPickerRow(
                    symbol: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill", color: Color(hex: "#8B5CF6"),
                    title: "mirror_menu", subtitle: "mirror_setting_help",
                    selection: $mirrorMode
                ) {
                    Text(String(localized: "mirror_normal")).tag(0)
                    Text(String(localized: "mirror_h")).tag(1)
                    Text(String(localized: "mirror_v")).tag(2)
                    Text(String(localized: "mirror_hv")).tag(3)
                }
                SettingsSliderRow(
                    symbol: "rectangle.inset.filled", color: Color(hex: "#F59E0B"), title: "label_content_padding",
                    subtitle: "content_padding_help",
                    value: $contentPadding, range: 0...40, step: 2, format: { "\(Int($0)) pt" })
            }
        }
    }
}

/// A few lines of script drawn the way the prompter shows them.
private struct PrompterPreview: View {
    let fontSize: Double
    let color: Color
    let opacity: Double
    let alignment: Int
    let mirror: Int
    let padding: Double

    private var textAlignment: TextAlignment {
        switch alignment {
        case 1: return .center
        case 2: return .trailing
        default: return .leading
        }
    }

    private var frameAlignment: Alignment {
        switch alignment {
        case 1: return .top
        case 2: return .topTrailing
        default: return .topLeading
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(SettingsPalette.previewBackdrop)
            VStack(spacing: 0) {
                UnevenRoundedRectangle(bottomLeadingRadius: 10, bottomTrailingRadius: 10)
                    .fill(Color.black)
                    .frame(width: 120, height: 18)
                Text(String(localized: "settings_preview_script"))
                    .font(.system(size: min(fontSize, 30)))
                    .foregroundStyle(color.opacity(opacity))
                    .multilineTextAlignment(textAlignment)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                    .padding(max(6, padding * 0.6))
                    .scaleEffect(x: mirror == 1 || mirror == 3 ? -1 : 1, y: mirror == 2 || mirror == 3 ? -1 : 1)
            }
            .frame(maxWidth: 440)
            .background(
                UnevenRoundedRectangle(bottomLeadingRadius: 14, bottomTrailingRadius: 14)
                    .fill(Color.black.opacity(0.92)))
            .clipped()
        }
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityHidden(true)
    }
}

// MARK: - Scrolling

struct ScrollingSettingsPage: View {
    @AppStorage(NotchyKeys.scrollSpeed) private var scrollSpeed: Double = 40
    @AppStorage(NotchyKeys.pauseOnHover) private var pauseOnHover = true
    @AppStorage(NotchyKeys.autoScrollPlaying) private var autoScrollPlaying = false

    var body: some View {
        SettingsPage {
            SettingsSectionTitle(title: "settings_page_scrolling", subtitle: "settings_scrolling_subtitle")
            SettingsGroup(footer: "scroll_speed_footer") {
                SettingsSliderRow(
                    symbol: "speedometer", color: SettingsPageID.scrolling.color, title: "label_scroll_speed",
                    subtitle: "scroll_speed_help",
                    value: $scrollSpeed, range: 10...120, step: 5, format: { String(format: String(localized: "points_per_second"), Int($0)) })
            }
            SettingsGroup {
                SettingsToggleRow(
                    symbol: "play.fill", color: Color(hex: "#22C55E"), title: "scroll_auto_short",
                    subtitle: "auto_scroll_help", isOn: $autoScrollPlaying)
                SettingsToggleRow(
                    symbol: "cursorarrow.rays", color: Color(hex: "#F59E0B"), title: "toggle_pause_on_hover",
                    subtitle: "pause_on_hover_help", isOn: $pauseOnHover)
            }
        }
    }
}

// MARK: - Voice

struct VoiceSettingsPage: View {
    @AppStorage(NotchyKeys.voiceControlEnabled) private var voiceControlEnabled = true
    @AppStorage(NotchyKeys.voiceMode) private var voiceModeRaw = VoiceMode.level.rawValue
    @AppStorage(NotchyKeys.micSensitivity) private var micSensitivity: Double = 50
    @AppStorage(NotchyKeys.preferredMicrophoneUID) private var preferredMicrophoneUID = ""
    @AppStorage(NotchyKeys.speechLocale) private var speechLocale = ""
    @AppStorage(NotchyKeys.highlightSpokenText) private var highlightSpokenText = true
    @ObservedObject private var follower = NotchyState.shared.speechFollower
    @ObservedObject private var audio = NotchyState.shared.audioMonitor
    @ObservedObject private var store = ScriptStore.shared
    @State private var microphones: [AudioDeviceList.Item] = []
    @State private var languages: [Locale] = []
    @State private var detectedLanguage: String?

    private var mode: VoiceMode { VoiceMode(rawValue: voiceModeRaw) ?? .level }

    var body: some View {
        SettingsPage {
            SettingsSectionTitle(title: "settings_page_voice", subtitle: "settings_voice_subtitle")
            SettingsGroup {
                SettingsToggleRow(
                    symbol: "mic.fill", color: SettingsPageID.voice.color, title: "toggle_listen",
                    subtitle: "voice_control_help", isOn: $voiceControlEnabled)
            }
            if audio.isDenied {
                SettingsGroup {
                    SettingsRow(symbol: "mic.slash.fill", color: Color(hex: "#6B7280"), title: "mic_denied_title",
                                subtitle: "mic_denied_help") {
                        Button(String(localized: "button_open_system_settings")) {
                            openPrivacy("Privacy_Microphone")
                        }
                    }
                }
            }
            HStack(spacing: 14) {
                VisualChoiceCard(title: "voice_mode_level", isSelected: mode == .level) {
                    voiceModeRaw = VoiceMode.level.rawValue
                } preview: {
                    VoiceModePreview(mode: .level)
                }
                VisualChoiceCard(title: "voice_mode_follow", isSelected: mode == .follow) {
                    voiceModeRaw = VoiceMode.follow.rawValue
                } preview: {
                    VoiceModePreview(mode: .follow)
                }
            }
            .disabled(!voiceControlEnabled)
            Text(String(localized: mode == .level ? "voice_mode_level_help" : "voice_mode_follow_help"))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            if mode == .follow {
                followStatus
                SettingsGroup(footer: "speech_language_footer") {
                    SettingsPickerRow(
                        symbol: "globe", color: Color(hex: "#3B82F6"), title: "picker_speech_language",
                        subtitle: autoLanguageSubtitle,
                        selection: $speechLocale
                    ) {
                        Text(String(localized: "speech_language_auto")).tag("")
                        Divider()
                        ForEach(languages, id: \.identifier) { locale in
                            Text(Locale.current.localizedString(forIdentifier: locale.identifier) ?? locale.identifier)
                                .tag(locale.identifier)
                        }
                    }
                    SettingsToggleRow(
                        symbol: "highlighter", color: Color(hex: "#EAB308"), title: "toggle_highlight_spoken",
                        subtitle: "highlight_spoken_help", isOn: $highlightSpokenText)
                }
                .disabled(!voiceControlEnabled)
            } else {
                SettingsGroup {
                    SettingsSliderRow(
                        symbol: "dial.medium.fill", color: Color(hex: "#F97316"), title: "label_sensitivity",
                        subtitle: "sensitivity_help",
                        value: $micSensitivity, range: 0...100, step: 5, format: sensitivityLabel)
                }
                .disabled(!voiceControlEnabled)
            }

            SettingsGroup(footer: "mic_picker_help_app") {
                SettingsPickerRow(
                    symbol: "mic.circle.fill", color: Color(hex: "#14B8A6"), title: "picker_microphone",
                    selection: $preferredMicrophoneUID
                ) {
                    Text(String(localized: "mic_system_default")).tag("")
                    ForEach(microphones) { device in
                        Text(device.name).tag(device.id)
                    }
                }
            }
            .disabled(!voiceControlEnabled)
        }
        .onAppear {
            microphones = AudioMonitor.inputDevicesForPicker()
        }
        .task {
            languages = await SpeechFollower.availableLocales()
        }
        .task(id: store.currentScriptBody) {
            let locale = await SpeechFollower.locale(forText: store.currentScriptBody)
            detectedLanguage = Locale.current.localizedString(forIdentifier: locale.identifier) ?? locale.identifier
        }
    }

    @ViewBuilder
    private var followStatus: some View {
        switch follower.status {
        case .denied:
            SettingsGroup {
                SettingsRow(symbol: "exclamationmark.bubble.fill", color: Color(hex: "#6B7280"),
                            title: "follow_status_denied_title", subtitle: "follow_status_denied_help") {
                    Button(String(localized: "button_open_system_settings")) {
                        openPrivacy("Privacy_SpeechRecognition")
                    }
                }
            }
        case .unsupportedLanguage(let name):
            SettingsGroup {
                SettingsRow(symbol: "character.bubble.fill", color: Color(hex: "#F59E0B"),
                            title: "follow_status_unsupported_title",
                            subtitle: String(format: String(localized: "follow_status_unsupported"), name)) {
                    EmptyView()
                }
            }
        case .downloadingLanguage(let name):
            SettingsGroup {
                SettingsRow(symbol: "arrow.down.circle.fill", color: Color(hex: "#0EA5E9"),
                            title: "follow_status_downloading_title",
                            subtitle: String(format: String(localized: "follow_status_downloading"), name)) {
                    ProgressView().controlSize(.small)
                }
            }
        default:
            EmptyView()
        }
    }

    private var autoLanguageSubtitle: String? {
        guard speechLocale.isEmpty, let detectedLanguage else { return nil }
        return String(format: String(localized: "speech_language_detected"), detectedLanguage)
    }

    private func sensitivityLabel(_ value: Double) -> String {
        if value < 25 { return String(localized: "sensitivity_low") }
        if value < 75 { return String(localized: "sensitivity_medium") }
        return String(localized: "sensitivity_high")
    }

    private func openPrivacy(_ anchor: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }
}

/// Little prompter with the two ways voice can drive it: steady bars of sound, or the word being read lit up.
private struct VoiceModePreview: View {
    let mode: VoiceMode

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if mode == .level {
                HStack(alignment: .center, spacing: 3) {
                    ForEach([6, 12, 18, 10, 16, 8, 14, 20, 9, 5], id: \.self) { h in
                        Capsule().fill(Color.white.opacity(0.8)).frame(width: 3, height: CGFloat(h))
                    }
                }
                .frame(height: 22)
                line(width: 120, opacity: 0.8)
                line(width: 96, opacity: 0.8)
            } else {
                line(width: 110, opacity: 0.3)
                HStack(spacing: 4) {
                    line(width: 30, opacity: 0.3)
                    Capsule().fill(Color.yellow.opacity(0.9)).frame(width: 30, height: 6)
                    line(width: 44, opacity: 0.85)
                }
                line(width: 118, opacity: 0.85)
                line(width: 84, opacity: 0.85)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.black.opacity(0.85)))
    }

    private func line(width: CGFloat, opacity: Double) -> some View {
        Capsule().fill(Color.white.opacity(opacity)).frame(width: width, height: 6)
    }
}

// MARK: - Notch

struct NotchSettingsPage: View {
    @AppStorage(NotchyKeys.preferredDisplayID) private var preferredDisplayID: Int = 0
    @AppStorage(NotchyKeys.windowWidth) private var windowWidth: Double = 0
    @AppStorage(NotchyKeys.windowHeight) private var windowHeight: Double = 320
    @AppStorage(NotchyKeys.windowOpacity) private var windowOpacity: Double = 1
    @AppStorage(NotchyKeys.notchBackgroundColorHex) private var notchBackgroundColorHex = "000000"
    @AppStorage(NotchyKeys.collapsedBarLabel) private var collapsedBarLabel = ""
    @AppStorage(NotchyKeys.buttonColorHex) private var buttonColorHex = "FFFFFF"
    @AppStorage(NotchyKeys.buttonOpacity) private var buttonOpacity: Double = 1
    @AppStorage(NotchyKeys.showInScreenCapture) private var showInScreenCapture = false
    /// Bumped when displays come and go, so the picker re-reads `NSScreen.screens`.
    @State private var screensChanged = 0

    private var controller: FloatingWindowController { NotchyState.shared.windowController }

    var body: some View {
        let _ = screensChanged
        SettingsPage {
            SettingsSectionTitle(title: "settings_page_notch", subtitle: "settings_notch_subtitle")
            SettingsGroup(footer: "monitor_help") {
                SettingsPickerRow(
                    symbol: "display", color: SettingsPageID.notch.color, title: "picker_monitor",
                    selection: $preferredDisplayID
                ) {
                    ForEach(screensForSelection(), id: \.id) { screen in
                        Text(screen.name).tag(screen.id)
                    }
                }
                SettingsRow(symbol: "pin.fill", color: Color(hex: "#EF4444"), title: "button_pin_back",
                            subtitle: "reset_notchy_help") {
                    Button(String(localized: "button_reset")) { resetWindow() }
                }
            }
            SettingsGroup(title: "section_size") {
                SettingsSliderRow(
                    symbol: "arrow.left.and.right", color: Color(hex: "#0EA5E9"), title: "label_width",
                    subtitle: "width_help",
                    value: $windowWidth, range: 0...1200, step: 20,
                    format: { $0 <= 0 ? String(localized: "label_auto") : "\(Int($0)) pt" })
                SettingsSliderRow(
                    symbol: "arrow.up.and.down", color: Color(hex: "#22C55E"), title: "label_expanded_height",
                    subtitle: "expanded_height_help",
                    value: $windowHeight, range: 200...600, step: 20, format: { "\(Int($0)) pt" })
            }
            SettingsGroup(title: "section_window_appearance") {
                SettingsSliderRow(
                    symbol: "square.on.square.dashed", color: Color(hex: "#64748B"), title: "label_window_opacity",
                    subtitle: "window_opacity_help",
                    value: $windowOpacity, range: 0...1, step: 0.05, format: { "\(Int(($0 * 100).rounded()))%" })
                SettingsColorRow(
                    symbol: "paintbrush.fill", color: Color(hex: "#111827"), title: "picker_notch_background",
                    subtitle: "notch_background_help",
                    selection: Binding(get: { colorFromHex(notchBackgroundColorHex) },
                                       set: { notchBackgroundColorHex = hexFromColor($0) }))
                SettingsRow(symbol: "character.cursor.ibeam", color: Color(hex: "#F97316"), title: "label_collapsed_bar",
                            subtitle: "collapsed_bar_help") {
                    TextField("", text: $collapsedBarLabel, prompt: Text(verbatim: "Notchy"))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 140)
                        .onChange(of: collapsedBarLabel) { _, newValue in
                            if newValue.count > 20 { collapsedBarLabel = String(newValue.prefix(20)) }
                        }
                }
            }
            SettingsGroup(title: "section_buttons") {
                SettingsColorRow(
                    symbol: "circle.hexagongrid.fill", color: Color(hex: "#8B5CF6"), title: "picker_button_color",
                    subtitle: "button_color_help",
                    selection: Binding(get: { colorFromHex(buttonColorHex) }, set: { buttonColorHex = hexFromColor($0) }))
                SettingsSliderRow(
                    symbol: "circle.dotted", color: Color(hex: "#64748B"), title: "label_button_opacity",
                    subtitle: "button_opacity_help",
                    value: $buttonOpacity, range: 0.1...1, step: 0.05, format: { "\(Int(($0 * 100).rounded()))%" })
            }
            SettingsGroup {
                SettingsToggleRow(
                    symbol: "record.circle", color: Color(hex: "#EF4444"), title: "toggle_show_in_capture",
                    subtitle: "show_in_capture_help", isOn: $showInScreenCapture)
            }
        }
        .onChange(of: preferredDisplayID) { _, id in controller.setPreferredDisplayID(id) }
        .onChange(of: windowWidth) { _, width in
            if width > 0 && width < 340 { windowWidth = 340 }
            controller.refreshWindowFrame()
        }
        .onChange(of: windowHeight) { _, _ in controller.refreshWindowFrame() }
        .onChange(of: showInScreenCapture) { _, _ in controller.applySharingType() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            screensChanged &+= 1
        }
    }

    private func resetWindow() {
        windowWidth = 0
        windowHeight = 320
        UserDefaults.standard.set(true, forKey: NotchyKeys.windowPinnedToNotch)
        controller.setTemporaryResize(width: nil, height: nil)
        controller.pinWindowToNotch()
    }
}

// MARK: - Editor

struct EditorSettingsPage: View {
    @AppStorage(NotchyKeys.scriptEditorFontSize) private var fontSize: Double = 14
    @AppStorage(NotchyKeys.scriptEditorTheme) private var themeRaw: Int = 0
    @AppStorage(NotchyKeys.scriptEditorLineSpacing) private var lineSpacing: Double = 1.2
    @AppStorage(NotchyKeys.scriptEditorFontName) private var fontName = ""

    var body: some View {
        SettingsPage {
            SettingsSectionTitle(title: "settings_page_editor", subtitle: "settings_editor_subtitle")
            SettingsGroup {
                SettingsSliderRow(
                    symbol: "textformat.size", color: SettingsPageID.editor.color, title: "label_font_size_editor",
                    value: $fontSize, range: 10...28, step: 1, format: { "\(Int($0)) pt" })
                SettingsPickerRow(
                    symbol: "circle.lefthalf.filled", color: Color(hex: "#6366F1"), title: "picker_editor_theme",
                    subtitle: "editor_theme_help",
                    selection: $themeRaw
                ) {
                    Text(String(localized: "theme_system")).tag(0)
                    Text(String(localized: "theme_light")).tag(1)
                    Text(String(localized: "theme_dark")).tag(2)
                }
                SettingsSliderRow(
                    symbol: "text.line.first.and.arrowtriangle.forward", color: Color(hex: "#0EA5E9"),
                    title: "label_line_spacing",
                    value: $lineSpacing, range: 0.8...2.5, step: 0.1, format: { String(format: "%.1f", $0) })
                SettingsRow(symbol: "textformat", color: Color(hex: "#F97316"), title: "field_font_name",
                            subtitle: "font_name_help") {
                    TextField("", text: $fontName, prompt: Text(verbatim: "Helvetica"))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 140)
                }
            }
        }
    }
}

// MARK: - General

struct GeneralSettingsPage: View {
    @StateObject private var launchAtLogin = LaunchAtLoginController()
    @State private var confirmingRestore = false

    var body: some View {
        SettingsPage {
            SettingsSectionTitle(title: "settings_page_general")
            SettingsGroup(footer: launchAtLogin.error) {
                SettingsToggleRow(
                    symbol: "power", color: Color(hex: "#22C55E"), title: "setting_open_at_login",
                    subtitle: "setting_open_at_login_help",
                    isOn: Binding(get: { launchAtLogin.isEnabled }, set: { launchAtLogin.setEnabled($0) }))
            }
            SettingsGroup {
                SettingsRow(symbol: "globe", color: Color(hex: "#3B82F6"), title: "section_language",
                            subtitle: "setting_language_help") {
                    Button(String(localized: "button_change")) {
                        // System Settings → General → Language & Region, where the Applications list sets it per app.
                        if let url = URL(string: "x-apple.systempreferences:com.apple.Localization-Settings.extension") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }
            SettingsGroup {
                SettingsRow(symbol: "folder.fill", color: Color(hex: "#0EA5E9"), title: "setting_your_scripts",
                            subtitle: "setting_your_scripts_help") {
                    Button(String(localized: "button_show_in_finder")) {
                        if let url = ScriptStore.shared.scriptsFolderURL {
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        }
                    }
                }
                SettingsRow(symbol: "square.and.arrow.up.fill", color: Color(hex: "#8B5CF6"), title: "export_all_scripts",
                            subtitle: "export_all_scripts_help") {
                    Button(String(localized: "button_export")) {
                        _ = ScriptStore.shared.exportAllScriptsToFolder()
                    }
                }
                SettingsRow(symbol: "arrow.counterclockwise", color: Color(hex: "#EF4444"), title: "setting_restore_defaults",
                            subtitle: "setting_restore_defaults_help") {
                    Button(String(localized: "button_restore")) { confirmingRestore = true }
                }
            }
        }
        .onAppear { launchAtLogin.refresh() }
        .confirmationDialog(String(localized: "restore_confirm_title"), isPresented: $confirmingRestore) {
            Button(String(localized: "restore_confirm_button"), role: .destructive) { restoreDefaults() }
        } message: {
            Text(String(localized: "restore_confirm_message"))
        }
    }

    private func restoreDefaults() {
        let keys = [
            NotchyKeys.scrollSpeed, NotchyKeys.fontSize, NotchyKeys.textColor, NotchyKeys.textOpacity,
            NotchyKeys.windowOpacity, NotchyKeys.windowWidth, NotchyKeys.windowHeight, NotchyKeys.windowPinnedToNotch,
            NotchyKeys.windowFreeOriginX, NotchyKeys.windowFreeOriginY, NotchyKeys.showInScreenCapture,
            NotchyKeys.buttonColorHex, NotchyKeys.buttonOpacity, NotchyKeys.notchBackgroundColorHex,
            NotchyKeys.collapsedBarLabel, NotchyKeys.voiceControlEnabled, NotchyKeys.autoScrollPlaying,
            NotchyKeys.pauseOnHover, NotchyKeys.micSensitivity, NotchyKeys.preferredMicrophoneUID,
            NotchyKeys.voiceMode, NotchyKeys.speechLocale, NotchyKeys.highlightSpokenText, NotchyKeys.mirrorMode,
            NotchyKeys.textAlignment, NotchyKeys.preferredDisplayID, NotchyKeys.contentPadding,
            NotchyKeys.scriptEditorFontSize, NotchyKeys.scriptEditorTheme, NotchyKeys.scriptEditorLineSpacing,
            NotchyKeys.scriptEditorFontName,
        ]
        keys.forEach(UserDefaults.standard.removeObject(forKey:))
        let controller = NotchyState.shared.windowController
        controller.setTemporaryResize(width: nil, height: nil)
        controller.applySharingType()
        controller.pinWindowToNotch()
    }
}

// MARK: - Shortcuts

struct ShortcutsSettingsPage: View {
    var body: some View {
        SettingsPage {
            SettingsSectionTitle(title: "settings_page_shortcuts", subtitle: "settings_shortcuts_subtitle")
            SettingsGroup(title: "shortcuts_group_anywhere", footer: "shortcuts_anywhere_footer") {
                ShortcutRow(symbol: "rectangle.topthird.inset.filled", title: "menu_toggle_prompter", keys: ["⌘", "⇧", "T"])
                ShortcutRow(symbol: "doc.text.fill", title: "menu_scripts", keys: ["⌘", "⇧", "R"])
                ShortcutRow(symbol: "pin.fill", title: "menu_pin_to_notch", keys: ["⌘", "⇧", "D"])
                ShortcutRow(symbol: "gearshape.fill", title: "menu_settings", keys: ["⌘", ","])
            }
            SettingsGroup(title: "shortcuts_group_prompter", footer: "shortcuts_prompter_footer") {
                ShortcutRow(symbol: "doc.on.clipboard.fill", title: "shortcut_paste", keys: ["⌘", "V"])
                ShortcutRow(symbol: "playpause.fill", title: "shortcut_play_pause", keys: ["Space"])
                ShortcutRow(symbol: "arrow.up.arrow.down", title: "shortcut_step", keys: ["↑", "↓"])
                ShortcutRow(symbol: "hare.fill", title: "shortcut_speed", keys: ["⇧", "↑", "↓"])
                ShortcutRow(symbol: "arrow.uturn.up", title: "menu_reset_scroll", keys: ["⌘", "0"])
            }
            SettingsGroup(title: "shortcuts_group_scripts") {
                ShortcutRow(symbol: "square.and.pencil", title: "new_script", keys: ["⌘", "N"])
                ShortcutRow(symbol: "play.rectangle.fill", title: "use_in_teleprompter", keys: ["⌘", "⇧", "P"])
                ShortcutRow(symbol: "bold", title: "help_bold", keys: ["⌘", "B"])
                ShortcutRow(symbol: "italic", title: "help_italic", keys: ["⌘", "I"])
            }
        }
    }
}

private struct ShortcutRow: View {
    let symbol: String
    let title: String
    let keys: [String]

    var body: some View {
        SettingsRow(symbol: symbol, color: SettingsPageID.shortcuts.color, title: title) {
            KeyCaps(keys: keys)
        }
    }
}

private struct KeyCaps: View {
    let keys: [String]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(keys, id: \.self) { key in
                Text(key == "Space" ? String(localized: "key_space") : key)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .padding(.horizontal, 7)
                    .frame(minWidth: 24, minHeight: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.primary.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.12)))
                    )
            }
        }
    }
}

// MARK: - About

struct AboutSettingsPage: View {
    @ObservedObject private var updates = UpdateChecker.shared

    private static let repo = URL(string: "https://github.com/lucianodiisouza/notchy-desktop-macos")!

    var body: some View {
        SettingsPage {
            VStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 96, height: 96)
                Text(verbatim: "Notchy")
                    .font(.system(size: 22, weight: .bold))
                Text(String(format: String(localized: "about_version"), AppVersion.marketingVersion, AppVersion.buildNumber))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Text(String(localized: "about_tagline"))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 24)

            SettingsGroup {
                if UpdateChecker.isEnabled {
                    SettingsRow(symbol: "arrow.down.circle.fill", color: Color(hex: "#22C55E"), title: "setting_updates",
                                subtitle: updateStatus) {
                        if let update = updates.availableUpdate {
                            Button(String(format: String(localized: "button_download_version"), update.version)) {
                                updates.openReleasePage()
                            }
                        } else {
                            Button(String(localized: "button_check_now")) { updates.checkForUpdates(force: true) }
                                .disabled(updates.isChecking)
                        }
                    }
                }
                SettingsRow(symbol: "chevron.left.forwardslash.chevron.right", color: SettingsPageID.about.color,
                            title: "setting_source_code", subtitle: "github.com/lucianodiisouza/notchy-desktop-macos") {
                    Button(String(localized: "button_open")) { NSWorkspace.shared.open(Self.repo) }
                }
                SettingsRow(symbol: "hand.raised.fill", color: Color(hex: "#3B82F6"), title: "setting_privacy",
                            subtitle: "setting_privacy_help") {
                    Button(String(localized: "button_read_policy")) {
                        NSWorkspace.shared.open(Self.repo.appendingPathComponent("blob/main/PRIVACY.md"))
                    }
                }
            }
        }
    }

    private var updateStatus: String {
        if updates.isChecking { return String(localized: "update_checking") }
        if let update = updates.availableUpdate {
            return String(format: String(localized: "update_available"), update.version)
        }
        if updates.lastChecked != nil { return String(localized: "update_latest") }
        return String(localized: "update_checks_github")
    }
}
