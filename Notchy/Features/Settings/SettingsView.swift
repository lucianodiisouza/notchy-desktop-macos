import SwiftUI
import AppKit

struct SettingsView: View {
    @AppStorage(NotchyKeys.scrollSpeed) private var scrollSpeed: Double = 40
    @AppStorage(NotchyKeys.fontSize) private var fontSize: Double = 16
    @AppStorage(NotchyKeys.textColor) private var textColorHex = "FFFFFF"
    @AppStorage(NotchyKeys.textOpacity) private var textOpacity: Double = 1
    @AppStorage(NotchyKeys.windowWidth) private var windowWidth: Double = 0
    @AppStorage(NotchyKeys.windowHeight) private var windowHeight: Double = 320
    @AppStorage(NotchyKeys.showInScreenCapture) private var showInScreenCapture: Bool = false
    @AppStorage(NotchyKeys.windowOpacity) private var windowOpacity: Double = 1
    @AppStorage(NotchyKeys.buttonOpacity) private var buttonOpacity: Double = 1
    @AppStorage(NotchyKeys.buttonColorHex) private var buttonColorHex = "FFFFFF"
    @AppStorage(NotchyKeys.voiceControlEnabled) private var voiceControlEnabled: Bool = true
    @AppStorage(NotchyKeys.micSensitivity) private var micSensitivity: Double = 50
    @AppStorage(NotchyKeys.preferredDisplayID) private var preferredDisplayID: Int = 0

    private let speedRange: ClosedRange<Double> = 10...120
    private let opacityRange: ClosedRange<Double> = 0...1
    private let fontSizeRange: ClosedRange<Double> = 10...32
    /// 0 = automática; mínimo 340 pt (abaixo disso corta bordas; entre 340–380 a barra quebra em duas linhas)
    private let widthRange: ClosedRange<Double> = 0...1200
    private let minWindowWidth: Double = 340
    private let heightRange: ClosedRange<Double> = 200...600
    private let sensitivityRange: ClosedRange<Double> = 0...100

    var body: some View {
        TabView {
            windowTab
            voiceTab
            textTab
            scrollTab
        }
        .tabViewStyle(.automatic)
        .frame(minWidth: 480, minHeight: 420)
        .onChange(of: windowWidth) { newValue in
            if newValue > 0 && newValue < minWindowWidth {
                windowWidth = minWindowWidth
            }
            NotchyState.shared.windowController.refreshWindowFrame()
        }
        .onChange(of: windowHeight) { _ in
            NotchyState.shared.windowController.refreshWindowFrame()
        }
    }

    // MARK: - Janela

    private var windowTab: some View {
        Form {
            Section(String(localized: "section_monitor")) {
                Picker(String(localized: "picker_monitor"), selection: $preferredDisplayID) {
                    ForEach(screensForSelection(), id: \.id) { screen in
                        Text(screen.name).tag(screen.id)
                    }
                }
                .onChange(of: preferredDisplayID) { _ in
                    NotchyState.shared.windowController.setPreferredDisplayID(preferredDisplayID)
                }
                Text(String(localized: "monitor_help"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(String(localized: "button_reset_notchy")) {
                    resetNotchy()
                }
                .buttonStyle(.bordered)
                Text(String(localized: "reset_notchy_help"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section(String(localized: "section_size")) {
                HStack {
                    Text(String(localized: "label_width"))
                    Slider(value: $windowWidth, in: widthRange, step: 20)
                    Text(widthLabel)
                        .frame(width: 70, alignment: .trailing)
                }
                Text(String(localized: "width_help"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Text(String(localized: "label_expanded_height"))
                    Slider(value: $windowHeight, in: heightRange, step: 20)
                    Text("\(Int(windowHeight)) pt")
                        .frame(width: 70, alignment: .trailing)
                }
                Text(String(localized: "expanded_height_help"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section(String(localized: "section_window_appearance")) {
                Toggle(String(localized: "toggle_show_in_capture"), isOn: $showInScreenCapture)
                    .onChange(of: showInScreenCapture) { _ in
                        NotchyState.shared.windowController.applySharingType()
                    }
                Text(String(localized: "show_in_capture_help"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Text(String(localized: "label_window_opacity"))
                    Slider(value: $windowOpacity, in: opacityRange, step: 0.05)
                    Text("\(Int(round(windowOpacity * 100)))%")
                        .frame(width: 36, alignment: .trailing)
                }
                .onChange(of: windowOpacity) { _ in
                    NotchyState.shared.windowController.applyWindowOpacity()
                }
                Text(String(localized: "window_opacity_help"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section(String(localized: "section_buttons")) {
                ColorPicker(String(localized: "picker_button_color"), selection: Binding(
                    get: { colorFromHex(buttonColorHex) },
                    set: { buttonColorHex = hexFromColor($0) }
                ))
                Text(String(localized: "button_color_help"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Text(String(localized: "label_button_opacity"))
                    Slider(value: $buttonOpacity, in: opacityRange, step: 0.05)
                    Text("\(Int(round(buttonOpacity * 100)))%")
                        .frame(width: 36, alignment: .trailing)
                }
                Text(String(localized: "button_opacity_help"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .tabItem { Label(String(localized: "settings_tab_window"), systemImage: "macwindow") }
    }

    // MARK: - Voz

    private var voiceTab: some View {
        Form {
            Section(String(localized: "section_voice_control")) {
                Toggle(String(localized: "toggle_voice_control"), isOn: $voiceControlEnabled)
                Text(String(localized: "voice_control_help"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Text(String(localized: "label_sensitivity"))
                    Slider(value: $micSensitivity, in: sensitivityRange, step: 5)
                    Text(sensitivityLabel)
                        .frame(width: 56, alignment: .trailing)
                }
                Text(String(localized: "sensitivity_help"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section(String(localized: "section_microphone")) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "mic_used_default"))
                        .font(.caption)
                    if !AudioMonitor.inputDeviceNames().isEmpty {
                        Text("Dispositivos: \(AudioMonitor.inputDeviceNames().joined(separator: ", "))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Button(String(localized: "button_open_sound_settings")) {
                        openSoundSettings()
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
        .tabItem { Label(String(localized: "settings_tab_voice"), systemImage: "mic.fill") }
    }

    // MARK: - Texto

    private var textTab: some View {
        Form {
            Section(String(localized: "section_font_color")) {
                HStack {
                    Text(String(localized: "label_font_size"))
                    Slider(value: $fontSize, in: fontSizeRange, step: 1)
                    Text("\(Int(fontSize)) pt")
                        .frame(width: 40, alignment: .trailing)
                }
                Text(String(localized: "font_size_help"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ColorPicker(String(localized: "picker_text_color"), selection: Binding(
                    get: { colorFromHex(textColorHex) },
                    set: { textColorHex = hexFromColor($0) }
                ))
                HStack {
                    Text(String(localized: "label_text_opacity"))
                    Slider(value: $textOpacity, in: opacityRange, step: 0.05)
                    Text("\(Int(round(textOpacity * 100)))%")
                        .frame(width: 36, alignment: .trailing)
                }
                Text(String(localized: "text_opacity_help"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .tabItem { Label(String(localized: "settings_tab_text"), systemImage: "textformat") }
    }

    // MARK: - Scroll

    private var scrollTab: some View {
        Form {
            Section(String(localized: "section_speed")) {
                HStack {
                    Text(String(localized: "label_scroll_speed"))
                    Slider(value: $scrollSpeed, in: speedRange, step: 5)
                    Text("\(Int(scrollSpeed)) pt/s")
                        .frame(width: 44, alignment: .trailing)
                }
                Text(String(localized: "scroll_speed_help"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                Text(String(localized: "voice_scroll_help"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .tabItem { Label(String(localized: "settings_tab_scroll"), systemImage: "arrow.up.arrow.down") }
    }

    // MARK: - Helpers

    private var widthLabel: String {
        if windowWidth <= 0 { return String(localized: "label_auto") }
        return "\(Int(windowWidth)) pt"
    }

    private var sensitivityLabel: String {
        if micSensitivity < 25 { return String(localized: "sensitivity_low") }
        if micSensitivity < 75 { return String(localized: "sensitivity_medium") }
        return String(localized: "sensitivity_high")
    }

    private func resetNotchy() {
        windowWidth = 0
        windowHeight = 320
        UserDefaults.standard.set(true, forKey: NotchyKeys.windowPinnedToNotch)
        NotchyState.shared.windowController.setTemporaryResize(width: nil, height: nil)
        NotchyState.shared.windowController.pinWindowToNotch()
    }

    private func openSoundSettings() {
        if #available(macOS 13.0, *) {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.sound")!)
        } else {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.sound")!)
        }
    }

}
