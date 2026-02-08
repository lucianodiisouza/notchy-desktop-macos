import SwiftUI
import AppKit

/// Settings for the Scripts editor: font, theme, line spacing, app language.
/// Language is stored in App Group so Notchy and Notchy Scripts stay in sync.
struct ScriptEditorSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(NotchyKeys.scriptEditorFontSize) private var fontSize: Double = 14
    @AppStorage(NotchyKeys.scriptEditorTheme) private var themeRaw: Int = 0
    @AppStorage(NotchyKeys.scriptEditorLineSpacing) private var lineSpacing: Double = 1.2
    @AppStorage(NotchyKeys.scriptEditorFontName) private var fontName: String = ""
    @State private var preferredLanguage: String = ""
    @State private var showLanguageRestartAlert = false

    private let fontSizeRange: ClosedRange<Double> = 10...28
    private let lineSpacingRange: ClosedRange<Double> = 0.8...2.5

    private var themeMode: ScriptEditorTheme {
        ScriptEditorTheme(rawValue: themeRaw) ?? .system
    }

    var body: some View {
        Form {
            Section(String(localized: "section_language")) {
                Picker(String(localized: "picker_language"), selection: $preferredLanguage) {
                    Text(String(localized: "language_system_default")).tag("")
                    ForEach(availableAppLocales, id: \.id) { locale in
                        Text(locale.displayName).tag(locale.id)
                    }
                }
                .onChange(of: preferredLanguage) { _ in
                    let oldGroup = UserDefaults(suiteName: NotchyKeys.appGroupIdentifier)?.string(forKey: NotchyKeys.preferredLanguage) ?? ""
                    syncPreferredLanguageToAppGroup()
                    if preferredLanguage != oldGroup {
                        showLanguageRestartAlert = true
                    }
                }
                .onAppear {
                    preferredLanguage = UserDefaults(suiteName: NotchyKeys.appGroupIdentifier)?.string(forKey: NotchyKeys.preferredLanguage) ?? ""
                }
                Text(String(localized: "language_restart_scripts_help"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .alert(String(localized: "language_restart_title"), isPresented: $showLanguageRestartAlert) {
                Button(String(localized: "language_restart_button")) {
                    showLanguageRestartAlert = false
                    restartScriptsToApplyLanguage()
                }
                Button(String(localized: "ok"), role: .cancel) { showLanguageRestartAlert = false }
            } message: {
                Text(String(localized: "language_restart_scripts_message"))
            }
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
        .liquidGlassBackground()
        .frame(minWidth: 360, minHeight: 320)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "ok")) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    // MARK: - Language (shared with Notchy via App Group)

    private struct AppLocale: Identifiable {
        let id: String
        let displayName: String
    }

    private var availableAppLocales: [AppLocale] {
        let ids = Bundle.main.localizations
            .filter { $0 != "Base" }
            .sorted { localeDisplayName(for: $0).localizedCaseInsensitiveCompare(localeDisplayName(for: $1)) == .orderedAscending }
        return ids.map { AppLocale(id: $0, displayName: localeDisplayName(for: $0)) }
    }

    private func localeDisplayName(for localeId: String) -> String {
        Locale.current.localizedString(forIdentifier: localeId) ?? localeId
    }

    private func syncPreferredLanguageToAppGroup() {
        UserDefaults(suiteName: NotchyKeys.appGroupIdentifier)?.set(preferredLanguage, forKey: NotchyKeys.preferredLanguage)
    }

    private func restartScriptsToApplyLanguage() {
        syncPreferredLanguageToAppGroup()
        if !preferredLanguage.isEmpty {
            UserDefaults.standard.set(preferredLanguage, forKey: NotchyKeys.preferredLanguage)
            UserDefaults.standard.set([preferredLanguage, "en"], forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.removeObject(forKey: NotchyKeys.preferredLanguage)
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
        UserDefaults.standard.synchronize()

        let scriptsURL = Bundle.main.bundleURL
        let scriptsPath = scriptsURL.path.replacingOccurrences(of: "'", with: "'\"'\"'")

        // Resolve main Notchy.app URL (menu bar / teleprompter): embedded or by bundle ID.
        var mainAppURL: URL?
        let bundleURL = Bundle.main.bundleURL
        let parentApp = bundleURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        if parentApp.lastPathComponent == "Notchy.app", FileManager.default.fileExists(atPath: parentApp.path) {
            mainAppURL = parentApp
        }
        if mainAppURL == nil {
            for id in NotchyKeys.mainAppBundleIdentifiers {
                if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
                    mainAppURL = url
                    break
                }
            }
        }

        // Quit main Notchy so it restarts with the new language.
        for id in NotchyKeys.mainAppBundleIdentifiers {
            let apps = NSRunningApplication.runningApplications(withBundleIdentifier: id)
            for app in apps {
                app.terminate()
            }
        }

        // Relaunch main app then Scripts after a short delay; then quit this app.
        let mainPath = mainAppURL?.path.replacingOccurrences(of: "'", with: "'\"'\"'") ?? ""
        let openBoth: String
        if !mainPath.isEmpty {
            openBoth = "sleep 1.2 && open '\(mainPath)' && sleep 0.8 && open '\(scriptsPath)'"
        } else {
            openBoth = "sleep 1.2 && open '\(scriptsPath)'"
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", openBoth]
        try? process.run()
        NSApplication.shared.terminate(nil)
    }
}

enum ScriptEditorTheme: Int {
    case system = 0
    case light = 1
    case dark = 2
}
