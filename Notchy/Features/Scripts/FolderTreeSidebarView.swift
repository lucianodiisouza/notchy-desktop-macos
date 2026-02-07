import SwiftUI

struct FolderTreeSidebarView: View {
    @ObservedObject var store: ScriptStore
    @Binding var selectedScriptId: UUID?
    @Binding var selectedFolderPath: String
    @Binding var expandedFolderPaths: Set<String>

    @State private var showNewFolderAlert = false
    @State private var newFolderName = ""
    @State private var newFolderParentPath = ""
    @State private var showDeleteFolderAlert = false
    @State private var folderToDelete: String?
    @State private var deleteFolderMode: DeleteFolderMode = .moveToParent
    @State private var showRenameFolderAlert = false
    @State private var folderToRename: String?
    @State private var renamedFolderName = ""

    enum DeleteFolderMode {
        case moveToParent
        case deleteAll
    }

    var body: some View {
        List(selection: $selectedScriptId) {
            Section {
                Button {
                    selectedFolderPath = ""
                    newFolderParentPath = ""
                    newFolderName = ""
                    showNewFolderAlert = true
                } label: {
                    Label("Nova pasta", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.borderless)

                folderRow(path: "", displayName: "Raiz")
                ForEach(subfolders(under: ""), id: \.self) { subpath in
                    folderSection(path: subpath)
                }
            } header: {
                Text("Pastas")
            }

            Section {
                ForEach(store.scripts(inFolderPath: selectedFolderPath)) { script in
                    ScriptRowView(
                        store: store,
                        script: script,
                        isSelectedForPrompter: store.selectedScriptId == script.id
                    ) {
                        selectedScriptId = script.id
                    }
                }
            } header: {
                HStack {
                    Text(selectedFolderPath.isEmpty ? "Roteiros (raiz)" : selectedFolderPath)
                    Spacer()
                    Button {
                        store.createScript(title: "Sem título", body: "", folderPath: selectedFolderPath)
                        if let newest = store.scripts(inFolderPath: selectedFolderPath).max(by: { $0.createdAt < $1.createdAt }) {
                            selectedScriptId = newest.id
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .listStyle(.sidebar)
        .alert("Nova pasta", isPresented: $showNewFolderAlert) {
            TextField("Nome da pasta", text: $newFolderName)
            Button("Cancelar", role: .cancel) {
                newFolderName = ""
                newFolderParentPath = ""
            }
            Button("Criar") {
                let path = newFolderParentPath.isEmpty ? newFolderName : newFolderParentPath + "/" + newFolderName
                store.createFolder(path: path)
                expandedFolderPaths.insert(newFolderParentPath)
                newFolderName = ""
                newFolderParentPath = ""
            }
        } message: {
            Text("Nome da nova pasta.")
        }
        .alert("Apagar pasta", isPresented: $showDeleteFolderAlert) {
            Button("Cancelar", role: .cancel) {
                folderToDelete = nil
            }
            Button("Mover roteiros para a pasta pai") {
                if let path = folderToDelete {
                    store.deleteFolder(path: path, moveScriptsToParent: true)
                }
                folderToDelete = nil
            }
            Button("Apagar pasta e todos os roteiros", role: .destructive) {
                if let path = folderToDelete {
                    store.deleteFolder(path: path, moveScriptsToParent: false)
                }
                folderToDelete = nil
            }
        } message: {
            Text(folderToDelete.map { "O que fazer com a pasta \"\(folderName(for: $0))\"?" } ?? "")
        }
        .alert("Renomear pasta", isPresented: $showRenameFolderAlert) {
            TextField("Nome", text: $renamedFolderName)
            Button("Cancelar", role: .cancel) {
                folderToRename = nil
                renamedFolderName = ""
            }
            Button("OK") {
                if let oldPath = folderToRename {
                    let newPath = parentPath(of: oldPath).isEmpty ? renamedFolderName : parentPath(of: oldPath) + "/" + renamedFolderName
                    store.renameFolder(oldPath: oldPath, newPath: newPath)
                }
                folderToRename = nil
                renamedFolderName = ""
            }
        } message: {
            Text("Novo nome da pasta.")
        }
    }

    private func folderName(for path: String) -> String {
        path.split(separator: "/").last.map(String.init) ?? path
    }

    private func parentPath(of path: String) -> String {
        let parts = path.split(separator: "/", omittingEmptySubsequences: true)
        if parts.count <= 1 { return "" }
        return parts.dropLast().joined(separator: "/")
    }

    private func subfolders(under path: String) -> [String] {
        store.subfolderPaths(under: path)
    }

    @ViewBuilder
    private func folderRow(path: String, displayName: String) -> some View {
        let name = path.isEmpty ? displayName : folderName(for: path)
        Button {
            selectedFolderPath = path
            selectedScriptId = nil
        } label: {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundStyle(.yellow)
                Text(name)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            if !path.isEmpty {
                Button("Renomear pasta") {
                    folderToRename = path
                    renamedFolderName = name
                    showRenameFolderAlert = true
                }
                Button("Nova subpasta") {
                    newFolderParentPath = path
                    newFolderName = ""
                    showNewFolderAlert = true
                }
                Button("Apagar pasta", role: .destructive) {
                    folderToDelete = path
                    showDeleteFolderAlert = true
                }
            }
        }
    }

    @ViewBuilder
    private func folderSection(path: String) -> some View {
        let name = folderName(for: path)
        DisclosureGroup(isExpanded: Binding(
            get: { expandedFolderPaths.contains(path) },
            set: { if $0 { expandedFolderPaths.insert(path) } else { expandedFolderPaths.remove(path) } }
        )) {
            ForEach(subfolders(under: path), id: \.self) { subpath in
                AnyView(folderSection(path: subpath))
            }
        } label: {
            Button {
                selectedFolderPath = path
                selectedScriptId = nil
            } label: {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.yellow)
                    Text(name)
                }
            }
            .buttonStyle(.plain)
        }
        .contextMenu {
            Button("Renomear pasta") {
                folderToRename = path
                renamedFolderName = name
                showRenameFolderAlert = true
            }
            Button("Nova subpasta") {
                newFolderParentPath = path
                newFolderName = ""
                showNewFolderAlert = true
            }
            Button("Apagar pasta", role: .destructive) {
                folderToDelete = path
                showDeleteFolderAlert = true
            }
        }
    }
}

struct ScriptRowView: View {
    @ObservedObject var store: ScriptStore
    let script: Script
    let isSelectedForPrompter: Bool
    let onSelect: () -> Void

    @State private var showDeleteConfirm = false

    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack {
                Image(systemName: "doc.text")
                VStack(alignment: .leading, spacing: 2) {
                    Text(script.title.isEmpty ? "Sem título" : script.title)
                        .lineLimit(1)
                    if isSelectedForPrompter {
                        Text("No teleprompter")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Usar no Teleprompter") {
                store.selectScript(id: script.id)
            }
            Button("Duplicar") {
                store.duplicateScript(id: script.id)
            }
            Divider()
            Button("Eliminar", role: .destructive) {
                showDeleteConfirm = true
            }
        }
        .confirmationDialog("Eliminar roteiro?", isPresented: $showDeleteConfirm) {
            Button("Eliminar", role: .destructive) {
                store.deleteScript(id: script.id)
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("O roteiro \"\(script.title)\" será eliminado.")
        }
    }
}
