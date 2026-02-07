import Foundation
import Combine
import AppKit
import UniformTypeIdentifiers

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
            title: NSLocalizedString("initial_script_title", comment: ""),
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
        DistributedNotificationCenter.default().post(name: Notification.Name(NotchyKeys.selectedScriptDidChangeNotification), object: nil)
    }

    /// Re-read scripts and selectedScriptId from App Group / disk (e.g. when Notchy Scripts changed selection). Call from main app when it receives selectedScriptDidChangeNotification.
    func syncFromSharedStorage() {
        load()
    }

    /// Call from Notchy Scripts when user chooses "Usar no Teleprompter". Opens the main Notchy app and shows the teleprompter (via notchy:// URL). Prefer opening with the parent app when Scripts is embedded so the URL is delivered reliably.
    static func openTeleprompterInMainApp() {
        guard let url = URL(string: NotchyKeys.openTeleprompterURLString) else { return }
        // When Scripts is embedded (Notchy.app/Contents/Applications/Notchy Scripts.app), open the URL with the parent app so it receives application(_:open:).
        let bundleURL = Bundle.main.bundleURL
        let app = bundleURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let notchyAppName = "Notchy.app"
        if app.lastPathComponent == notchyAppName, FileManager.default.fileExists(atPath: app.path) {
            let config = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open([url], withApplicationAt: app, configuration: config) { _, error in
                if error != nil {
                    NSWorkspace.shared.open(url)
                }
            }
            return
        }
        NSWorkspace.shared.open(url)
    }

    // MARK: - CRUD

    /// Creates a script and reloads. Returns the new script's id on success, nil on failure.
    @discardableResult
    func createScript(title: String, body: String, folderPath: String = "") -> UUID? {
        let script = Script(title: title, body: body, folderPath: folderPath)
        do {
            try repository.create(script)
            load()
            return script.id
        } catch {
            return nil
        }
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

    /// When `clearRTF` is true, sets `script.bodyRTF = nil`. Otherwise if `bodyRTF` is non-nil, sets it.
    func updateScript(id: UUID, title: String?, body: String?, bodyRTF: Data? = nil, clearRTF: Bool = false) {
        guard var script = scripts.first(where: { $0.id == id }) else { return }
        let titleChanged = title.map { $0 != script.title } ?? false
        let bodyChanged = body.map { $0 != script.body } ?? false
        let rtfChanged: Bool = clearRTF ? (script.bodyRTF != nil) : (bodyRTF.map { $0 != script.bodyRTF } ?? false)
        guard titleChanged || bodyChanged || rtfChanged else { return }
        if let t = title { script.title = t }
        if let b = body { script.body = b }
        if clearRTF { script.bodyRTF = nil }
        else if let rtf = bodyRTF { script.bodyRTF = rtf }
        script.updatedAt = Date()
        do {
            try repository.update(script)
            load()
        } catch {}
    }

    /// Atualiza o corpo do script selecionado (ex.: colar no teleprompter). Limpa RTF para manter corpo como texto puro.
    func updateCurrentScriptBody(_ body: String) {
        guard let id = selectedScriptId else { return }
        updateScript(id: id, title: nil, body: body, bodyRTF: nil, clearRTF: true)
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
            title: script.title + NSLocalizedString("script_copy_suffix", comment: ""),
            body: script.body,
            bodyRTF: script.bodyRTF,
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

    // MARK: - Export

    /// Presents save panel and exports the script body as plain text. Returns true if user saved.
    func exportScriptAsTXT(id: UUID) -> Bool {
        guard let script = scripts.first(where: { $0.id == id }) else { return false }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = sanitizedFileName(for: script.title) + ".txt"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        do {
            try script.body.write(to: url, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }

    /// Presents open panel to choose a folder, then exports all scripts as .txt preserving folder structure. Returns true if exported.
    func exportAllScriptsToFolder() -> Bool {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = NSLocalizedString("export_choose_folder", comment: "")
        guard panel.runModal() == .OK, let baseURL = panel.url else { return false }
        let exportFolder = baseURL.appendingPathComponent("Notchy Scripts Export", isDirectory: true)
        let fileManager = FileManager.default
        do {
            if fileManager.fileExists(atPath: exportFolder.path) {
                try fileManager.removeItem(at: exportFolder)
            }
            try fileManager.createDirectory(at: exportFolder, withIntermediateDirectories: true)
            for script in scripts {
                let folderPath = script.folderPath
                let targetDir: URL
                if folderPath.isEmpty {
                    targetDir = exportFolder
                } else {
                    let subpath = folderPath.split(separator: "/").map(String.init).joined(separator: "/")
                    targetDir = exportFolder.appendingPathComponent(subpath, isDirectory: true)
                    try fileManager.createDirectory(at: targetDir, withIntermediateDirectories: true)
                }
                let fileName = sanitizedFileName(for: script.title) + ".txt"
                let fileURL = targetDir.appendingPathComponent(fileName, isDirectory: false)
                try script.body.write(to: fileURL, atomically: true, encoding: .utf8)
            }
            return true
        } catch {
            return false
        }
    }

    private func sanitizedFileName(for title: String) -> String {
        let t = title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "Untitled" : t
    }
}
