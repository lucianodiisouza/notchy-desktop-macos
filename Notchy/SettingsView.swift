import SwiftUI
import AppKit

struct SettingsView: View {
    @AppStorage("scrollSpeed") private var scrollSpeed: Double = 40
    @AppStorage("fontSize") private var fontSize: Double = 16
    @AppStorage("textColor") private var textColorHex = "FFFFFF"
    @AppStorage("textOpacity") private var textOpacity: Double = 1
    @AppStorage("windowWidth") private var windowWidth: Double = 0
    @AppStorage("windowHeight") private var windowHeight: Double = 320
    @AppStorage("showInScreenCapture") private var showInScreenCapture: Bool = false
    @AppStorage("windowOpacity") private var windowOpacity: Double = 1
    @AppStorage("buttonOpacity") private var buttonOpacity: Double = 1
    @AppStorage("buttonColorHex") private var buttonColorHex = "FFFFFF"
    @AppStorage("voiceControlEnabled") private var voiceControlEnabled: Bool = true
    @AppStorage("micSensitivity") private var micSensitivity: Double = 50
    @AppStorage(preferredDisplayIDKey) private var preferredDisplayID: Int = 0

    private let speedRange: ClosedRange<Double> = 10...120
    private let opacityRange: ClosedRange<Double> = 0...1
    private let fontSizeRange: ClosedRange<Double> = 10...32
    private let widthRange: ClosedRange<Double> = 0...1200
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
        .onChange(of: windowWidth) { _ in
            NotchyState.shared.windowController.refreshWindowFrame()
        }
        .onChange(of: windowHeight) { _ in
            NotchyState.shared.windowController.refreshWindowFrame()
        }
    }

    // MARK: - Janela

    private var windowTab: some View {
        Form {
            Section("Monitor e posição") {
                Picker("Monitor", selection: $preferredDisplayID) {
                    ForEach(screensForSelection(), id: \.id) { screen in
                        Text(screen.name).tag(screen.id)
                    }
                }
                .onChange(of: preferredDisplayID) { _ in
                    NotchyState.shared.windowController.setPreferredDisplayID(preferredDisplayID)
                }
                Text("Escolha em qual tela o Notchy aparece (na faixa do notch/menu bar).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Resetar Notchy") {
                    resetNotchy()
                }
                .buttonStyle(.bordered)
                Text("Volta a janela para o notch, largura automática e altura 320 pt.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Tamanho") {
                HStack {
                    Text("Largura")
                    Slider(value: $windowWidth, in: widthRange, step: 20)
                    Text(widthLabel)
                        .frame(width: 70, alignment: .trailing)
                }
                Text("0 = automática (largura total do notch). Defina um valor para largura fixa (centralizada).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Text("Altura expandida")
                    Slider(value: $windowHeight, in: heightRange, step: 20)
                    Text("\(Int(windowHeight)) pt")
                        .frame(width: 70, alignment: .trailing)
                }
                Text("Altura da janela do teleprompter quando expandida (200–600 pt).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Aparência da janela") {
                Toggle("Aparecer em gravação de tela", isOn: $showInScreenCapture)
                    .onChange(of: showInScreenCapture) { _ in
                        NotchyState.shared.windowController.applySharingType()
                    }
                Text("Desative o \"stealth\" para que o Notchy apareça em gravações e screenshots.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Text("Opacidade da janela")
                    Slider(value: $windowOpacity, in: opacityRange, step: 0.05)
                    Text("\(Int(round(windowOpacity * 100)))%")
                        .frame(width: 36, alignment: .trailing)
                }
                .onChange(of: windowOpacity) { _ in
                    NotchyState.shared.windowController.applyWindowOpacity()
                }
                Text("Transparência da janela do Notchy (0–100%).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Botões e ícones") {
                ColorPicker("Cor dos botões", selection: Binding(
                    get: { colorFromHex(buttonColorHex) },
                    set: { buttonColorHex = hexFromColor($0) }
                ))
                Text("Cor dos ícones da barra (mic, play, recolher, arrastar).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Text("Opacidade dos ícones")
                    Slider(value: $buttonOpacity, in: opacityRange, step: 0.05)
                    Text("\(Int(round(buttonOpacity * 100)))%")
                        .frame(width: 36, alignment: .trailing)
                }
                Text("Transparência dos botões e ícones da barra.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .tabItem { Label("Janela", systemImage: "macwindow") }
    }

    // MARK: - Voz

    private var voiceTab: some View {
        Form {
            Section("Controle por voz") {
                Toggle("Controle por voz (rolar ao falar)", isOn: $voiceControlEnabled)
                Text("Desligue se não quiser que o texto avance ao detectar voz (ex.: outras pessoas na sala).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Text("Sensibilidade")
                    Slider(value: $micSensitivity, in: sensitivityRange, step: 5)
                    Text(sensitivityLabel)
                        .frame(width: 56, alignment: .trailing)
                }
                Text("Menor = só voz mais alta aciona. Maior = qualquer som pode acionar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Microfone") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Microfone usado: padrão do sistema")
                        .font(.caption)
                    if !AudioMonitor.inputDeviceNames().isEmpty {
                        Text("Dispositivos: \(AudioMonitor.inputDeviceNames().joined(separator: ", "))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Button("Abrir Ajustes de Som do sistema") {
                        openSoundSettings()
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
        .tabItem { Label("Voz", systemImage: "mic.fill") }
    }

    // MARK: - Texto

    private var textTab: some View {
        Form {
            Section("Fonte e cor") {
                HStack {
                    Text("Tamanho da fonte")
                    Slider(value: $fontSize, in: fontSizeRange, step: 1)
                    Text("\(Int(fontSize)) pt")
                        .frame(width: 40, alignment: .trailing)
                }
                Text("Ajuste o tamanho do texto do teleprompter.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ColorPicker("Cor do texto", selection: Binding(
                    get: { colorFromHex(textColorHex) },
                    set: { textColorHex = hexFromColor($0) }
                ))
                HStack {
                    Text("Opacidade do texto")
                    Slider(value: $textOpacity, in: opacityRange, step: 0.05)
                    Text("\(Int(round(textOpacity * 100)))%")
                        .frame(width: 36, alignment: .trailing)
                }
                Text("Transparência apenas do texto do teleprompter.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .tabItem { Label("Texto", systemImage: "textformat") }
    }

    // MARK: - Scroll

    private var scrollTab: some View {
        Form {
            Section("Velocidade") {
                HStack {
                    Text("Velocidade do scroll")
                    Slider(value: $scrollSpeed, in: speedRange, step: 5)
                    Text("\(Int(scrollSpeed)) pt/s")
                        .frame(width: 44, alignment: .trailing)
                }
                Text("Velocidade com que o texto sobe durante a apresentação.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                Text("Com controle por voz ativo, o scroll começa ao falar e pausa após um breve silêncio. Use Shift+↑/↓ para mudar a velocidade durante a apresentação.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .tabItem { Label("Scroll", systemImage: "arrow.up.arrow.down") }
    }

    // MARK: - Helpers

    private var widthLabel: String {
        if windowWidth <= 0 { return "Auto" }
        return "\(Int(windowWidth)) pt"
    }

    private var sensitivityLabel: String {
        if micSensitivity < 25 { return "Baixa" }
        if micSensitivity < 75 { return "Média" }
        return "Alta"
    }

    private func resetNotchy() {
        windowWidth = 0
        windowHeight = 320
        UserDefaults.standard.set(true, forKey: "windowPinnedToNotch")
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

    private func colorFromHex(_ hex: String) -> Color {
        let s = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: s).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        return Color(red: r, green: g, blue: b)
    }

    private func hexFromColor(_ color: Color) -> String {
        let ns = NSColor(color)
        let r = Int((ns.redComponent * 255).rounded())
        let g = Int((ns.greenComponent * 255).rounded())
        let b = Int((ns.blueComponent * 255).rounded())
        return String(format: "%02X%02X%02X", r, g, b)
    }
}
