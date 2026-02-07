import Foundation
import Combine

/// Shared store for scripts and folder tree. Uses App Group for persistence.
/// Used by both Notchy (read/write for teleprompter + paste) and Notchy Scripts (full UI).
final class ScriptStore: ObservableObject {
    static let shared = ScriptStore()

    private let repository: ScriptRepositoryProtocol
    private let userDefaults: UserDefaults?

    @Published private(set) var scripts: [Script] = []
    @Published private(set) var folderPaths: [String] = []
    @Published private(set) var selectedScriptId: UUID?

    /// Script currently selected for the teleprompter (if any).
    var currentScript: Script? {
        guard let id = selectedScriptId else { return nil }
        return scripts.first { $0.id == id }
    }

    /// Body of the script selected for the teleprompter. Empty string if none.
    var currentScriptBody: String {
        currentScript?.body ?? ""
    }

    private init(repository: ScriptRepositoryProtocol = ScriptRepository(), userDefaults: UserDefaults? = UserDefaults(suiteName: NotchyKeys.appGroupIdentifier)) {
        self.repository = repository
        self.userDefaults = userDefaults
        self.selectedScriptId = userDefaults?.string(forKey: NotchyKeys.selectedScriptId).flatMap { UUID(uuidString: $0) }
        load()
    }

    private func load() {
        runMigrationIfNeeded()
        do {
            scripts = try repository.getAll()
            folderPaths = try repository.getFolderPaths()
            selectedScriptId = userDefaults?.string(forKey: NotchyKeys.selectedScriptId).flatMap { UUID(uuidString: $0) }
        } catch {
            scripts = []
            folderPaths = []
        }
    }

    /// First-run: if legacy prompterText exists, create "Roteiro inicial" script and set as selected.
    private func runMigrationIfNeeded() {
        let standard = UserDefaults.standard
        if standard.bool(forKey: NotchyKeys.scriptsMigrationDone) { return }
        standard.set(true, forKey: NotchyKeys.scriptsMigrationDone)
        guard let text = standard.string(forKey: NotchyKeys.prompterText),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let script = Script(
            title: "Roteiro inicial",
            body: text,
            folderPath: ""
        )
        do {
            try repository.create(script)
            persistSelectedScriptId(script.id)
        } catch {}
    }

    private func persistSelectedScriptId(_ id: UUID?) {
        if let id = id {
            userDefaults?.set(id.uuidString, forKey: NotchyKeys.selectedScriptId)
        } else {
            userDefaults?.removeObject(forKey: NotchyKeys.selectedScriptId)
        }
        selectedScriptId = id
    }

    // MARK: - Selection

    func selectScript(id: UUID?) {
        persistSelectedScriptId(id)
    }

    // MARK: - CRUD

    func createScript(title: String, body: String, folderPath: String = "") {
        let script = Script(title: title, body: body, folderPath: folderPath)
        do {
            try repository.create(script)
            load()
        } catch {}
    }

    /// Create a script from pasted text (e.g. in teleprompter). Title from first line or date; folderPath = "".
    func createScript(fromPaste pastedText: String) -> Script? {
        let title = Script.titleFromFirstLine(pastedText, fallback: Script.titleFromPasteDate())
        let script = Script(title: title, body: pastedText, folderPath: "")
        do {
            try repository.create(script)
            load()
            persistSelectedScriptId(script.id)
            return script
        } catch {
            return nil
        }
    }

    func updateScript(id: UUID, title: String?, body: String?) {
        guard var script = scripts.first(where: { $0.id == id }) else { return }
        if let t = title { script.title = t }
        if let b = body { script.body = b }
        script.updatedAt = Date()
        do {
            try repository.update(script)
            load()
        } catch {}
    }

    func updateCurrentScriptBody(_ body: String) {
        guard let id = selectedScriptId else { return }
        updateScript(id: id, title: nil, body: body)
    }

    func deleteScript(id: UUID) {
        do {
            try repository.delete(id: id)
            if selectedScriptId == id {
                persistSelectedScriptId(nil)
            }
            load()
        } catch {}
    }

    func duplicateScript(id: UUID) {
        guard let script = scripts.first(where: { $0.id == id }) else { return }
        let copy = Script(
            title: script.title + " (cópia)",
            body: script.body,
            folderPath: script.folderPath
        )
        do {
            try repository.create(copy)
            load()
        } catch {}
    }

    // MARK: - Folders

    func createFolder(path: String) {
        do {
            try repository.createFolder(path: path)
            load()
        } catch {}
    }

    func deleteFolder(path: String, moveScriptsToParent: Bool) {
        do {
            if moveScriptsToParent {
                let parentPath = parentPath(of: path)
                for script in scripts where script.folderPath == path || script.folderPath.hasPrefix(path + "/") {
                    try repository.moveScript(id: script.id, newFolderPath: parentPath)
                }
            } else {
                for script in scripts where script.folderPath == path || script.folderPath.hasPrefix(path + "/") {
                    try repository.delete(id: script.id)
                    if selectedScriptId == script.id {
                        persistSelectedScriptId(nil)
                    }
                }
            }
            try repository.deleteFolder(path: path)
            load()
        } catch {}
    }

    func moveScript(id: UUID, newFolderPath: String) {
        do {
            try repository.moveScript(id: id, newFolderPath: newFolderPath)
            load()
        } catch {}
    }

    func renameFolder(oldPath: String, newPath: String) {
        do {
            try repository.renameFolder(oldPath: oldPath, newPath: newPath)
            load()
        } catch {}
    }

    /// Parent path: "Trabalho/2025" -> "Trabalho", "Trabalho" -> ""
    private func parentPath(of path: String) -> String {
        let parts = path.split(separator: "/", omittingEmptySubsequences: true)
        if parts.count <= 1 { return "" }
        return parts.dropLast().joined(separator: "/")
    }

    // MARK: - Tree helpers for UI

    /// All unique folder path segments for building tree. Root = "" not included as a "folder" name.
    func scripts(inFolderPath path: String) -> [Script] {
        scripts
            .filter { $0.folderPath == path }
            .sorted { ($0.updatedAt, $0.id.uuidString) > ($1.updatedAt, $1.id.uuidString) }
    }

    /// Subfolder paths directly under the given path. e.g. path "" -> ["Trabalho", "Pessoal"], path "Trabalho" -> ["Trabalho/2025"]
    func subfolderPaths(under path: String) -> [String] {
        let prefix = path.isEmpty ? "" : path + "/"
        var seen = Set<String>()
        for p in folderPaths {
            if p.hasPrefix(prefix), p != path {
                let remainder = String(p.dropFirst(prefix.count))
                let firstSegment = remainder.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init) ?? remainder
                let subpath = path.isEmpty ? firstSegment : path + "/" + firstSegment
                seen.insert(subpath)
            }
        }
        for script in scripts {
            let p = script.folderPath
            if p.hasPrefix(prefix), p != path, !p.isEmpty {
                let remainder = String(p.dropFirst(prefix.count))
                let firstSegment = remainder.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init) ?? remainder
                let subpath = path.isEmpty ? firstSegment : path + "/" + firstSegment
                seen.insert(subpath)
            }
        }
        return seen.sorted()
    }
}
