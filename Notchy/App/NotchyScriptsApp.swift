import SwiftUI

@main
struct NotchyScriptsApp: App {
    @FocusedValue(\.selectedScriptId) private var selectedScriptId

    var body: some Scene {
        WindowGroup {
            ScriptsWindowContent()
                .frame(minWidth: 600, minHeight: 400)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Usar no Teleprompter") {
                    if let id = selectedScriptId {
                        ScriptStore.shared.selectScript(id: id)
                    }
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                .disabled(selectedScriptId == nil)
            }
        }
    }
}
