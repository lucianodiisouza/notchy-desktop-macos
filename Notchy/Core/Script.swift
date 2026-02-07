import Foundation

/// A script (roteiro) for the teleprompter. Can be organized in folders via `folderPath`.
struct Script: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var body: String
    /// Folder path in tree, e.g. "" = root, "Trabalho" = top-level folder, "Trabalho/2025" = subfolder.
    var folderPath: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        body: String,
        folderPath: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.folderPath = folderPath
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Title derived from first line of body (max 50 chars), or fallback.
    static func titleFromFirstLine(_ body: String, fallback: String = "Sem título") -> String {
        let line = body
            .split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map(String.init)
            ?? ""
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return fallback }
        if trimmed.count <= 50 { return trimmed }
        return String(trimmed.prefix(47)) + "..."
    }

    /// Fallback title for pasted content, e.g. "Colar em 07/02/25".
    static func titleFromPasteDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return "Colar em \(formatter.string(from: Date()))"
    }
}
