import Foundation

protocol ScriptRepositoryProtocol: AnyObject {
    func getAll() throws -> [Script]
    func get(id: UUID) throws -> Script?
    func create(_ script: Script) throws
    func update(_ script: Script) throws
    func delete(id: UUID) throws
    func getFolderPaths() throws -> [String]
    func createFolder(path: String) throws
    func deleteFolder(path: String) throws
    func moveScript(id: UUID, newFolderPath: String) throws
    func renameFolder(oldPath: String, newPath: String) throws
    var scriptsFolderURL: URL? { get }
}

/// Persists scripts in the App Group container. Flat storage: Scripts/{id}.json with folderPath inside JSON.
/// Folder list in Scripts/.folders (newline-separated paths).
final class ScriptRepository: ScriptRepositoryProtocol {
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let scriptsDirectoryName = "Scripts"
    private let foldersFileName = ".folders"

    private var containerURL: URL? {
        fileManager.containerURL(forSecurityApplicationGroupIdentifier: NotchyKeys.appGroupIdentifier)
    }

    private var scriptsDirectoryURL: URL? {
        guard let container = containerURL else { return nil }
        return container.appendingPathComponent(scriptsDirectoryName, isDirectory: true)
    }

    private func scriptFileURL(id: UUID) -> URL? {
        scriptsDirectoryURL?.appendingPathComponent("\(id.uuidString).json", isDirectory: false)
    }

    private var foldersFileURL: URL? {
        scriptsDirectoryURL?.appendingPathComponent(foldersFileName, isDirectory: false)
    }

    private func ensureScriptsDirectory() throws {
        guard let url = scriptsDirectoryURL else {
            throw ScriptRepositoryError.noContainer
        }
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    /// The folder holding one JSON file per script, for "Show in Finder".
    var scriptsFolderURL: URL? {
        try? ensureScriptsDirectory()
        return scriptsDirectoryURL
    }

    private func loadFolderPaths() throws -> [String] {
        guard let url = foldersFileURL else { return [] }
        guard fileManager.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        guard let string = String(data: data, encoding: .utf8) else { return [] }
        return string
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func saveFolderPaths(_ paths: [String]) throws {
        try ensureScriptsDirectory()
        guard let url = foldersFileURL else { throw ScriptRepositoryError.noContainer }
        let string = paths.sorted().joined(separator: "\n")
        try (string + "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - ScriptRepositoryProtocol

    func getAll() throws -> [Script] {
        try ensureScriptsDirectory()
        guard let dir = scriptsDirectoryURL else { return [] }
        let contents = try fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        var scripts: [Script] = []
        for url in contents where url.pathExtension == "json" && url.lastPathComponent != foldersFileName {
            do {
                let data = try Data(contentsOf: url)
                scripts.append(try decoder.decode(Script.self, from: data))
            } catch {
                AppLogger.error("Could not read script \(url.lastPathComponent): \(error)")
            }
        }
        return scripts
    }

    func get(id: UUID) throws -> Script? {
        guard let url = scriptFileURL(id: id),
              fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let script = try? decoder.decode(Script.self, from: data) else {
            return nil
        }
        return script
    }

    func create(_ script: Script) throws {
        try ensureScriptsDirectory()
        guard let url = scriptFileURL(id: script.id) else { throw ScriptRepositoryError.noContainer }
        let data = try encoder.encode(script)
        try data.write(to: url, options: .atomic)
    }

    func update(_ script: Script) throws {
        var updated = script
        updated.updatedAt = Date()
        try create(updated)
    }

    func delete(id: UUID) throws {
        guard let url = scriptFileURL(id: id) else { return }
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    func getFolderPaths() throws -> [String] {
        try loadFolderPaths()
    }

    func createFolder(path: String) throws {
        let normalized = path.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "//", with: "/")
        guard !normalized.isEmpty else { return }
        var paths = try loadFolderPaths()
        if !paths.contains(normalized) {
            paths.append(normalized)
            try saveFolderPaths(paths)
        }
    }

    /// Removes the folder and every folder inside it, so none of them comes back in the tree.
    func deleteFolder(path: String) throws {
        var paths = try loadFolderPaths()
        paths.removeAll { $0 == path || $0.hasPrefix(path + "/") }
        try saveFolderPaths(paths)
    }

    func moveScript(id: UUID, newFolderPath: String) throws {
        guard var script = try get(id: id) else { return }
        script.folderPath = newFolderPath
        script.updatedAt = Date()
        try update(script)
    }

    func renameFolder(oldPath: String, newPath: String) throws {
        let scripts = try getAll()
        for script in scripts where script.folderPath == oldPath || script.folderPath.hasPrefix(oldPath + "/") {
            var updated = script
            if script.folderPath == oldPath {
                updated.folderPath = newPath
            } else {
                updated.folderPath = newPath + String(script.folderPath.dropFirst(oldPath.count))
            }
            updated.updatedAt = Date()
            try update(updated)
        }
        var paths = try loadFolderPaths()
        if let idx = paths.firstIndex(of: oldPath) {
            paths[idx] = newPath
        }
        paths = paths.map { p in
            if p == oldPath { return newPath }
            if p.hasPrefix(oldPath + "/") { return newPath + String(p.dropFirst(oldPath.count)) }
            return p
        }
        try saveFolderPaths(paths)
    }
}

enum ScriptRepositoryError: Error {
    case noContainer
}
