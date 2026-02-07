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
            Section(String(localized: "section_editor_appearance")) {
                HStack {
                    Text(String(localized: "label_font_size_editor"))
                    Slider(value: $fontSize, in: fontSizeRange, step: 1)
                    Text("\(Int(fontSize)) pt")
                        .frame(width: 36, alignment: .trailing)
                }
                Picker(String(localized: "picker_editor_theme"), selection: $themeRaw) {
                    Text(String(localized: "theme_system")).tag(0)
                    Text(String(localized: "theme_light")).tag(1)
                    Text(String(localized: "theme_dark")).tag(2)
                }
                .pickerStyle(.segmented)
                Text(String(localized: "editor_theme_help"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Text(String(localized: "label_line_spacing"))
                    Slider(value: $lineSpacing, in: lineSpacingRange, step: 0.1)
                    Text(String(format: "%.1f", lineSpacing))
                        .frame(width: 28, alignment: .trailing)
                }
            }
            Section(String(localized: "section_font")) {
                TextField(String(localized: "field_font_name"), text: $fontName)
                    .textFieldStyle(.roundedBorder)
                Text(String(localized: "font_name_help"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section(String(localized: "section_markdown")) {
                Text(String(localized: "markdown_help"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 360, minHeight: 320)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "ok")) { dismiss() }
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
