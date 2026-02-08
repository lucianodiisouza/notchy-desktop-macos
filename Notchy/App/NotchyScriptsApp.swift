import SwiftUI

@main
struct NotchyScriptsApp: App {
    @FocusedValue(\.selectedScriptId) private var selectedScriptId
    @State private var showScriptsSettings = false

    init() {
        // Use same language as main Notchy app (synced via App Group). Set before any UI loads.
        let suite = UserDefaults(suiteName: NotchyKeys.appGroupIdentifier)
        let pref = suite?.string(forKey: NotchyKeys.preferredLanguage) ?? ""
        if !pref.isEmpty {
            UserDefaults.standard.set(pref, forKey: NotchyKeys.preferredLanguage)
            UserDefaults.standard.set([pref, "en"], forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.removeObject(forKey: NotchyKeys.preferredLanguage)
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
        PreferredLanguageBundle.installIfNeeded()
        PremiumService.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ScriptsWindowContent(showScriptsSettings: $showScriptsSettings)
                .frame(minWidth: 600, minHeight: 400)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button(String(localized: "use_in_teleprompter")) {
                    if let id = selectedScriptId {
                        ScriptStore.shared.selectScript(id: id)
                        ScriptStore.openTeleprompterInMainApp()
                    }
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                .disabled(selectedScriptId == nil)
            }
            CommandGroup(after: .appSettings) {
                Button(String(localized: "menu_editor_settings")) {
                    showScriptsSettings = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
