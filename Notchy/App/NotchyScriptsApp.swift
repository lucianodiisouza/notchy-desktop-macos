import SwiftUI

@main
struct NotchyScriptsApp: App {
    @FocusedValue(\.selectedScriptId) private var selectedScriptId
    @State private var showScriptsSettings = false

    var body: some Scene {
        WindowGroup {
            ScriptsWindowContent(showScriptsSettings: $showScriptsSettings)
                .frame(minWidth: 600, minHeight: 400)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Usar no Teleprompter") {
                    if let id = selectedScriptId {
                        ScriptStore.shared.selectScript(id: id)
                        ScriptStore.openTeleprompterInMainApp()
                    }
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                .disabled(selectedScriptId == nil)
            }
            CommandGroup(after: .appSettings) {
                Button("Configurações do editor…") {
                    showScriptsSettings = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
