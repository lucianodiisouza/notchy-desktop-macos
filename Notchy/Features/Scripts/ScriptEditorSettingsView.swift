import SwiftUI

/// Settings for the Scripts editor: font, theme, line spacing.
/// Stored in UserDefaults (App Group key can be used if shared with main app).
struct ScriptEditorSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(NotchyKeys.scriptEditorFontSize) private var fontSize: Double = 14
    @AppStorage(NotchyKeys.scriptEditorTheme) private var themeRaw: Int = 0
    @AppStorage(NotchyKeys.scriptEditorLineSpacing) private var lineSpacing: Double = 1.2
    @AppStorage(NotchyKeys.scriptEditorFontName) private var fontName: String = ""

    private let fontSizeRange: ClosedRange<Double> = 10...28
    private let lineSpacingRange: ClosedRange<Double> = 0.8...2.5

    private var themeMode: ScriptEditorTheme {
        ScriptEditorTheme(rawValue: themeRaw) ?? .system
    }

    var body: some View {
        Form {
            Section("Aparência do editor") {
                HStack {
                    Text("Tamanho da fonte")
                    Slider(value: $fontSize, in: fontSizeRange, step: 1)
                    Text("\(Int(fontSize)) pt")
                        .frame(width: 36, alignment: .trailing)
                }
                Picker("Tema do editor", selection: $themeRaw) {
                    Text("Sistema").tag(0)
                    Text("Claro").tag(1)
                    Text("Escuro").tag(2)
                }
                .pickerStyle(.segmented)
                Text("Claro = fundo branco; Escuro = fundo preto. O tema só afeta esta janela do editor.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Text("Espaçamento entre linhas")
                    Slider(value: $lineSpacing, in: lineSpacingRange, step: 0.1)
                    Text(String(format: "%.1f", lineSpacing))
                        .frame(width: 28, alignment: .trailing)
                }
            }
            Section("Fonte") {
                TextField("Nome da fonte (vazio = sistema)", text: $fontName)
                    .textFieldStyle(.roundedBorder)
                Text("Deixe em branco para usar a fonte do sistema. Ex.: Helvetica, Menlo.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Markdown") {
                Text("Nos blocos de texto você vê negrito, itálico, sublinhado e tamanho em tempo real. Use a barra (B, I, U, tamanho) ou digite **negrito**, *itálico*, %sublinhado% e [14]tamanho[/14]. O teleprompter exibe texto puro (formatação removida).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 360, minHeight: 320)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("OK") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
    }
}

enum ScriptEditorTheme: Int {
    case system = 0
    case light = 1
    case dark = 2
}
