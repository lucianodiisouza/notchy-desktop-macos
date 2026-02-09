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
        content
    }

    private var content: some View {
        NavigationSplitView {
            FolderTreeSidebarView(
                store: store,
                selectedScriptId: $selectedScriptId,
                selectedFolderPath: $selectedFolderPath,
                expandedFolderPaths: $expandedFolderPaths
            )
        } detail: {
            if let id = selectedScriptId, let script = store.scripts.first(where: { $0.id == id }) {
                ScriptEditorView(store: store, script: script)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text(String(localized: "select_script_placeholder"))
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text(String(localized: "select_script_help"))
                        .font(.body)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .liquidGlassBackground()
        .navigationTitle("")
        .focusedValue(\.selectedScriptId, selectedScriptId)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    if let id = store.createScript(
                        title: String(localized: "script_untitled"),
                        body: "",
                        folderPath: selectedFolderPath
                    ) {
                        selectedScriptId = id
                        store.selectScript(id: id)
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .help(String(localized: "new_script"))
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    showScriptsSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .help(String(localized: "help_editor_settings"))
            }
        }
        .sheet(isPresented: $showScriptsSettings) {
            ScriptEditorSettingsView()
        }
        .preferredColorScheme(colorScheme)
    }
}
