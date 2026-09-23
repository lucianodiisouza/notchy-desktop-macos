import SwiftUI
import UniformTypeIdentifiers

/// Drag payload: plain text with this prefix so we recognise script drops. Value = "notchy-script:" + uuidString.
private let scriptDragPrefix = "notchy-script:"

private let folderColor = Color(hex: "#F59E0B")
private let scriptColor = Color(hex: "#64748B")
private let prompterColor = Color(hex: "#EA580C")

/// The Scripts window's sidebar, drawn like the settings window's: search on top, then the scripts at the root and the
/// folders with theirs, the window's wallpaper showing faintly through.
struct FolderTreeSidebarView: View {
    @ObservedObject var store: ScriptStore
    @Binding var selectedScriptId: UUID?
    @Binding var selectedFolderPath: String
    @Binding var expandedFolderPaths: Set<String>
    var onNewScript: () -> Void

    @State private var query = ""
    @FocusState private var isSearching: Bool
    @State private var showNewFolderAlert = false
    @State private var newFolderName = ""
    @State private var newFolderParentPath = ""
    @State private var showDeleteFolderAlert = false
    @State private var folderToDelete: String?
    @State private var showRenameFolderAlert = false
    @State private var folderToRename: String?
    @State private var renamedFolderName = ""
    @State private var isRootDropTarget = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            searchField
                // Clears the traffic lights, which sit on the sidebar.
                .padding(.top, 44)
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if query.trimmingCharacters(in: .whitespaces).isEmpty {
                        tree
                    } else {
                        results
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.never)
            // Dropping a script on the empty part of the list moves it out of its folder.
            .background(isRootDropTarget ? Color.accentColor.opacity(0.08) : Color.clear)
            .onDrop(of: [.plainText], isTargeted: $isRootDropTarget) { providers in
                acceptScriptDrop(providers: providers, folderPath: "")
            }
            footer
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background { SidebarMaterial() }
        .overlay(alignment: .trailing) {
            Rectangle().fill(Color.primary.opacity(0.1)).frame(width: 1)
        }
        .background {
            Button("") { isSearching = true }
                .keyboardShortcut("f", modifiers: .command)
                .hidden()
        }
        .alert(String(localized: "new_folder"), isPresented: $showNewFolderAlert) {
            TextField(String(localized: "folder_name"), text: $newFolderName)
            Button(String(localized: "cancel"), role: .cancel) {
                newFolderName = ""
                newFolderParentPath = ""
            }
            Button(String(localized: "create")) {
                let name = newFolderName.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return }
                let path = newFolderParentPath.isEmpty ? name : newFolderParentPath + "/" + name
                store.createFolder(path: path)
                expandedFolderPaths.insert(newFolderParentPath)
                expandedFolderPaths.insert(path)
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
                if let oldPath = folderToRename, !renamedFolderName.trimmingCharacters(in: .whitespaces).isEmpty {
                    let parent = parentPath(of: oldPath)
                    let newPath = parent.isEmpty ? renamedFolderName : parent + "/" + renamedFolderName
                    store.renameFolder(oldPath: oldPath, newPath: newPath)
                }
                folderToRename = nil
                renamedFolderName = ""
            }
        } message: {
            Text(String(localized: "rename_folder_message"))
        }
    }

    // MARK: - Parts

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(String(localized: "scripts_search"), text: $query)
                .textFieldStyle(.plain)
                .focused($isSearching)
                .onExitCommand { query = "" }
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .font(.system(size: 13))
        .padding(.horizontal, 9)
        .frame(height: 30)
        .background(
            Capsule().fill(Color.primary.opacity(0.06))
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.1)))
        )
    }

    /// Root scripts first, then the folders, each opening onto its subfolders and scripts.
    @ViewBuilder
    private var tree: some View {
        let rootScripts = store.scripts(inFolderPath: "")
        let folders = store.subfolderPaths(under: "")
        if rootScripts.isEmpty && folders.isEmpty {
            Text(String(localized: "scripts_empty"))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.top, 24)
        }
        ForEach(rootScripts) { script in
            scriptRow(script, folder: "", depth: 0)
        }
        if !rootScripts.isEmpty && !folders.isEmpty {
            // Groups apart by a gap, not a heading, like System Settings.
            Spacer().frame(height: 10)
        }
        ForEach(folders, id: \.self) { path in
            folderBranch(path: path, depth: 0)
        }
    }

    /// Scripts whose title or text matches, flat.
    @ViewBuilder
    private var results: some View {
        let needle = query.trimmingCharacters(in: .whitespaces)
        let found = store.scripts
            .filter { $0.title.localizedCaseInsensitiveContains(needle) || $0.body.localizedCaseInsensitiveContains(needle) }
            .sorted { $0.updatedAt > $1.updatedAt }
        if found.isEmpty {
            Text(String(localized: "settings_no_results"))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
        }
        ForEach(found) { script in
            scriptRow(script, folder: script.folderPath, depth: 0)
        }
    }

    private func folderBranch(path: String, depth: Int) -> AnyView {
        let isOpen = expandedFolderPaths.contains(path)
        return AnyView(
            VStack(alignment: .leading, spacing: 2) {
                FolderRow(
                    name: folderName(for: path),
                    depth: depth,
                    isOpen: isOpen,
                    isSelected: selectedFolderPath == path && selectedScriptId == nil,
                    onDropScript: { acceptScriptDrop(providers: $0, folderPath: path) }
                ) {
                    selectedFolderPath = path
                    selectedScriptId = nil
                    if isOpen { expandedFolderPaths.remove(path) } else { expandedFolderPaths.insert(path) }
                }
                .contextMenu {
                    Button(String(localized: "new_script")) {
                        selectedFolderPath = path
                        expandedFolderPaths.insert(path)
                        onNewScript()
                    }
                    Button(String(localized: "new_subfolder")) {
                        newFolderParentPath = path
                        newFolderName = ""
                        showNewFolderAlert = true
                    }
                    Button(String(localized: "rename_folder")) {
                        folderToRename = path
                        renamedFolderName = folderName(for: path)
                        showRenameFolderAlert = true
                    }
                    Divider()
                    Button(String(localized: "delete_folder"), role: .destructive) {
                        folderToDelete = path
                        showDeleteFolderAlert = true
                    }
                }
                if isOpen {
                    ForEach(store.subfolderPaths(under: path), id: \.self) { sub in
                        folderBranch(path: sub, depth: depth + 1)
                    }
                    ForEach(store.scripts(inFolderPath: path)) { script in
                        scriptRow(script, folder: path, depth: depth + 1)
                    }
                }
            }
        )
    }

    private func scriptRow(_ script: Script, folder: String, depth: Int) -> some View {
        ScriptRowView(
            store: store,
            script: script,
            depth: depth,
            isSelected: selectedScriptId == script.id,
            isSelectedForPrompter: store.selectedScriptId == script.id
        ) {
            selectedFolderPath = folder
            selectedScriptId = script.id
        }
    }

    private var footer: some View {
        HStack(spacing: 4) {
            FooterButton(symbol: "square.and.pencil", help: "new_script", action: onNewScript)
            FooterButton(symbol: "folder.badge.plus", help: "new_folder") {
                newFolderParentPath = ""
                newFolderName = ""
                showNewFolderAlert = true
            }
            Spacer()
            FooterButton(symbol: "gearshape", help: "help_editor_settings") {
                AppDelegate.shared?.showSettingsWindow(.editor)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    // MARK: - Helpers

    private func folderName(for path: String) -> String {
        path.split(separator: "/").last.map(String.init) ?? path
    }

    private func parentPath(of path: String) -> String {
        let parts = path.split(separator: "/", omittingEmptySubsequences: true)
        if parts.count <= 1 { return "" }
        return parts.dropLast().joined(separator: "/")
    }

    private func acceptScriptDrop(providers: [NSItemProvider], folderPath: String) -> Bool {
        guard let provider = providers.first,
              provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) else { return false }
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
}

// MARK: - Rows

/// A folder: chevron, yellow folder icon and name. Tapping opens or closes it; scripts can be dropped on it.
private struct FolderRow: View {
    let name: String
    let depth: Int
    let isOpen: Bool
    let isSelected: Bool
    let onDropScript: ([NSItemProvider]) -> Bool
    let action: () -> Void

    @State private var isDropTarget = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isOpen ? 90 : 0))
                    .frame(width: 10)
                SettingsIcon(symbol: "folder.fill", color: folderColor, size: 22)
                Text(name)
                    .font(.system(size: 13))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.leading, CGFloat(depth) * 16 + 2)
            .padding(.trailing, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isDropTarget ? Color.accentColor.opacity(0.25) : (isSelected ? Color.primary.opacity(0.08) : .clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isOpen)
        .onDrop(of: [.plainText], isTargeted: $isDropTarget, perform: onDropScript)
    }
}

/// A script: document icon (orange while it is the one on the prompter) and title, filled with the accent color while it
/// is open in the editor.
struct ScriptRowView: View {
    @ObservedObject var store: ScriptStore
    let script: Script
    let depth: Int
    let isSelected: Bool
    let isSelectedForPrompter: Bool
    let onSelect: () -> Void

    @State private var showDeleteConfirm = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                SettingsIcon(
                    symbol: isSelectedForPrompter ? "text.aligncenter" : "doc.text.fill",
                    color: isSelectedForPrompter ? prompterColor : scriptColor,
                    size: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(script.title.isEmpty ? String(localized: "script_untitled") : script.title)
                        .font(.system(size: 13))
                        .lineLimit(1)
                    if isSelectedForPrompter {
                        Text(String(localized: "in_teleprompter"))
                            .font(.system(size: 10))
                            .foregroundStyle(isSelected ? Color.white.opacity(0.8) : Color.secondary)
                    }
                }
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                Spacer(minLength: 0)
            }
            // Scripts in a folder line up with the folder's name (past its chevron).
            .padding(.leading, CGFloat(depth) * 16 + (depth > 0 ? 20 : 2))
            .padding(.trailing, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onDrag {
            NSItemProvider(object: (scriptDragPrefix + script.id.uuidString) as NSString)
        }
        .contextMenu {
            Button(String(localized: "use_in_teleprompter")) {
                store.showInTeleprompter(id: script.id)
            }
            Button(String(localized: "duplicate")) {
                store.duplicateScript(id: script.id)
            }
            Button(String(localized: "export_script")) {
                _ = store.exportScriptAsTXT(id: script.id)
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

private struct FooterButton: View {
    let symbol: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help.localized)
    }
}
