import SwiftUI
import UniformTypeIdentifiers

/// Drag payload: plain text with this prefix so we recognise script drops. Value = "notchy-script:" + uuidString.
private let scriptDragPrefix = "notchy-script:"

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
                    Label(String(localized: "new_folder"), systemImage: "folder.badge.plus")
                }
                .buttonStyle(.borderless)

                rootFolderSection()
                ForEach(subfolders(under: ""), id: \.self) { subpath in
                    folderSection(path: subpath)
                }
            } header: {
                Text(String(localized: "folders_header"))
            }
        }
        .listStyle(.sidebar)
        .alert(String(localized: "new_folder"), isPresented: $showNewFolderAlert) {
            TextField(String(localized: "folder_name"), text: $newFolderName)
            Button(String(localized: "cancel"), role: .cancel) {
                newFolderName = ""
                newFolderParentPath = ""
            }
            Button(String(localized: "create")) {
                let path = newFolderParentPath.isEmpty ? newFolderName : newFolderParentPath + "/" + newFolderName
                store.createFolder(path: path)
                expandedFolderPaths.insert(newFolderParentPath)
                newFolderName = ""
                newFolderParentPath = ""
            }
        } message: {
            Text(String(localized: "new_folder_message"))
        }
        .alert(String(localized: "delete_folder"), isPresented: $showDeleteFolderAlert) {
            Button(String(localized: "cancel"), role: .cancel) {
                folderToDelete = nil
            }
            Button(String(localized: "move_scripts_to_parent")) {
                if let path = folderToDelete {
                    store.deleteFolder(path: path, moveScriptsToParent: true)
                }
                folderToDelete = nil
            }
            Button(String(localized: "delete_folder_and_scripts"), role: .destructive) {
                if let path = folderToDelete {
                    store.deleteFolder(path: path, moveScriptsToParent: false)
                }
                folderToDelete = nil
            }
        } message: {
            Text(folderToDelete.map { String(format: NSLocalizedString("delete_folder_message", comment: ""), folderName(for: $0)) } ?? "")
        }
        .alert(String(localized: "rename_folder"), isPresented: $showRenameFolderAlert) {
            TextField(String(localized: "field_name"), text: $renamedFolderName)
            Button(String(localized: "cancel"), role: .cancel) {
                folderToRename = nil
                renamedFolderName = ""
            }
            Button(String(localized: "ok")) {
                if let oldPath = folderToRename {
                    let newPath = parentPath(of: oldPath).isEmpty ? renamedFolderName : parentPath(of: oldPath) + "/" + renamedFolderName
                    store.renameFolder(oldPath: oldPath, newPath: newPath)
                }
                folderToRename = nil
                renamedFolderName = ""
            }
        } message: {
            Text(String(localized: "rename_folder_message"))
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
    private func rootFolderSection() -> some View {
        DisclosureGroup(isExpanded: Binding(
            get: { expandedFolderPaths.contains("") },
            set: { if $0 { expandedFolderPaths.insert("") } else { expandedFolderPaths.remove("") } }
        )) {
            ForEach(store.scripts(inFolderPath: "")) { script in
                ScriptRowView(
                    store: store,
                    script: script,
                    isSelectedForPrompter: store.selectedScriptId == script.id
                ) {
                    selectedFolderPath = ""
                    selectedScriptId = script.id
                }
            }
        } label: {
            Button {
                selectedFolderPath = ""
                selectedScriptId = nil
            } label: {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.yellow)
                    Text(String(localized: "root"))
                }
            }
            .buttonStyle(.plain)
        }
        .onDrop(of: [.plainText], isTargeted: nil) { providers in
            acceptScriptDrop(providers: providers, folderPath: "")
        }
        .contextMenu {
            Button(String(localized: "new_script")) {
                expandedFolderPaths.insert("")
                store.createScript(title: NSLocalizedString("script_untitled", comment: ""), body: "", folderPath: "")
                if let newest = store.scripts(inFolderPath: "").max(by: { $0.createdAt < $1.createdAt }) {
                    selectedScriptId = newest.id
                }
            }
            Button(String(localized: "new_subfolder")) {
                newFolderParentPath = ""
                newFolderName = ""
                showNewFolderAlert = true
            }
        }
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
        .onDrop(of: [.plainText], isTargeted: nil) { providers in
            acceptScriptDrop(providers: providers, folderPath: path)
        }
        .contextMenu {
            if !path.isEmpty {
                Button(String(localized: "rename_folder")) {
                    folderToRename = path
                    renamedFolderName = name
                    showRenameFolderAlert = true
                }
                Button(String(localized: "new_subfolder")) {
                    newFolderParentPath = path
                    newFolderName = ""
                    showNewFolderAlert = true
                }
                Button(String(localized: "delete_folder"), role: .destructive) {
                    folderToDelete = path
                    showDeleteFolderAlert = true
                }
            }
        }
    }

    private func acceptScriptDrop(providers: [NSItemProvider], folderPath: String) -> Bool {
        guard let provider = providers.first else { return false }
        guard provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) else { return false }
        provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
            let string: String? = (item as? String) ?? (item as? Data).flatMap { String(data: $0, encoding: .utf8) }
            guard let raw = string?.trimmingCharacters(in: .whitespaces),
                  raw.hasPrefix(scriptDragPrefix),
                  let id = UUID(uuidString: String(raw.dropFirst(scriptDragPrefix.count))) else { return }
            DispatchQueue.main.async {
                store.moveScript(id: id, newFolderPath: folderPath)
                if !folderPath.isEmpty { expandedFolderPaths.insert(folderPath) }
                selectedFolderPath = folderPath
            }
        }
        return true
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
            ForEach(store.scripts(inFolderPath: path)) { script in
                ScriptRowView(
                    store: store,
                    script: script,
                    isSelectedForPrompter: store.selectedScriptId == script.id
                ) {
                    selectedFolderPath = path
                    selectedScriptId = script.id
                }
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
        .onDrop(of: [.plainText], isTargeted: nil) { providers in
            acceptScriptDrop(providers: providers, folderPath: path)
        }
        .contextMenu {
            Button(String(localized: "new_script")) {
                expandedFolderPaths.insert(path)
                store.createScript(title: NSLocalizedString("script_untitled", comment: ""), body: "", folderPath: path)
                if let newest = store.scripts(inFolderPath: path).max(by: { $0.createdAt < $1.createdAt }) {
                    selectedFolderPath = path
                    selectedScriptId = newest.id
                }
            }
            Button(String(localized: "rename_folder")) {
                folderToRename = path
                renamedFolderName = name
                showRenameFolderAlert = true
            }
            Button(String(localized: "new_subfolder")) {
                newFolderParentPath = path
                newFolderName = ""
                showNewFolderAlert = true
            }
            Button(String(localized: "delete_folder"), role: .destructive) {
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
                    Text(script.title.isEmpty ? String(localized: "script_untitled") : script.title)
                        .lineLimit(1)
                    if isSelectedForPrompter {
                        Text(String(localized: "in_teleprompter"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .onDrag {
            NSItemProvider(object: (scriptDragPrefix + script.id.uuidString) as NSString)
        }
        .contextMenu {
            Button(String(localized: "use_in_teleprompter")) {
                store.selectScript(id: script.id)
                ScriptStore.openTeleprompterInMainApp()
            }
            Button(String(localized: "duplicate")) {
                store.duplicateScript(id: script.id)
            }
            Divider()
            Button(String(localized: "delete"), role: .destructive) {
                showDeleteConfirm = true
            }
        }
        .confirmationDialog(String(localized: "delete_script_confirm_title"), isPresented: $showDeleteConfirm) {
            Button(String(localized: "delete"), role: .destructive) {
                store.deleteScript(id: script.id)
            }
            Button(String(localized: "cancel"), role: .cancel) {}
        } message: {
            Text(String(format: NSLocalizedString("delete_script_confirm_message", comment: ""), script.title))
        }
    }
}
