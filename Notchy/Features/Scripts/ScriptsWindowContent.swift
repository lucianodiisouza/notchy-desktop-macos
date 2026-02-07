import SwiftUI

private struct SelectedScriptIdKey: FocusedValueKey {
    typealias Value = UUID?
}

extension FocusedValues {
    var selectedScriptId: UUID? {
        get { self[SelectedScriptIdKey.self] ?? nil }
        set { self[SelectedScriptIdKey.self] = newValue }
    }
}

/// Root view for Notchy Scripts: sidebar (folder tree + script list) + editor.
struct ScriptsWindowContent: View {
    @Binding var showScriptsSettings: Bool

    @StateObject private var store = ScriptStore.shared
    @State private var selectedScriptId: UUID?
    @State private var selectedFolderPath: String = ""
    @State private var expandedFolderPaths: Set<String> = []
    @AppStorage(NotchyKeys.scriptEditorTheme) private var themeRaw: Int = 0

    private var colorScheme: ColorScheme? {
        switch themeRaw {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }

    var body: some View {
        NavigationSplitView {
            FolderTreeSidebarView(
                store: store,
                selectedScriptId: $selectedScriptId,
                selectedFolderPath: $selectedFolderPath,
                expandedFolderPaths: $expandedFolderPaths
            )
        } detail: {
            if let id = selectedScriptId, let script = store.scripts.first(where: { $0.id == id }) {
                ScriptEditorView(store: store, script: script, onOpenSettings: { showScriptsSettings = true })
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("Selecione um roteiro")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Escolha um roteiro na lista ou crie um novo.")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(selectedScriptId.flatMap { id in store.scripts.first(where: { $0.id == id })?.title } ?? "Roteiros")
        .focusedValue(\.selectedScriptId, selectedScriptId)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    showScriptsSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .help("Configurações do editor")
            }
        }
        .sheet(isPresented: $showScriptsSettings) {
            ScriptEditorSettingsView()
        }
        .preferredColorScheme(colorScheme)
    }
}
