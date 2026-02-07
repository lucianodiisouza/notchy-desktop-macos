import Foundation

/// Bloco editável no estilo Notion: o usuário vê e interage com tabela, lista, etc.
enum ScriptBlock: Equatable {
    case paragraph(String)
    case heading(Int, String)  // level 1...6, text
    case bulletedList([String])
    case numberedList([String])
    /// Primeira linha = cabeçalho, demais = dados. Sempre pelo menos 1 linha e 1 coluna.
    case table(rows: [[String]])

    // MARK: - Markdown → Blocos

    static func parse(markdown: String) -> [ScriptBlock] {
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map { String($0) }
        var i = 0
        var blocks: [ScriptBlock] = []

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Tabela: linhas consecutivas com |
            if trimmed.contains("|") {
                var tableRows: [[String]] = []
                var j = i
                while j < lines.count, lines[j].trimmingCharacters(in: .whitespaces).contains("|") {
                    let row = lines[j]
                        .split(separator: "|", omittingEmptySubsequences: false)
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                    if row.isEmpty { break }
                    let isSeparator = row.allSatisfy { cell in
                        cell.trimmingCharacters(in: .whitespaces).allSatisfy { $0 == "-" || $0 == ":" || $0 == " " }
                    }
                    if !isSeparator {
                        tableRows.append(row)
                    }
                    j += 1
                }
                if !tableRows.isEmpty {
                    blocks.append(.table(rows: tableRows))
                    i = j
                    continue
                }
            }

            // Heading # .. ######
            if let m = trimmed.range(of: "^#{1,6}\\s+", options: .regularExpression) {
                let level = trimmed[trimmed.startIndex..<m.upperBound].filter { $0 == "#" }.count
                let text = String(trimmed[m.upperBound...])
                blocks.append(.heading(min(level, 6), text))
                i += 1
                continue
            }

            // Lista com marcador
            if trimmed.range(of: "^(?:[-*+])\\s+", options: .regularExpression) != nil {
                var items: [String] = []
                var j = i
                while j < lines.count {
                    let li = lines[j].trimmingCharacters(in: .whitespaces)
                    guard let mm = li.range(of: "^(?:[-*+])\\s+", options: .regularExpression) else { break }
                    items.append(String(li[mm.upperBound...]))
                    j += 1
                }
                blocks.append(.bulletedList(items))
                i = j
                continue
            }

            // Lista numerada
            if trimmed.range(of: "^\\d+\\.\\s+", options: .regularExpression) != nil {
                var items: [String] = []
                var j = i
                while j < lines.count {
                    let li = lines[j].trimmingCharacters(in: .whitespaces)
                    guard let mm = li.range(of: "^\\d+\\.\\s+", options: .regularExpression) else { break }
                    items.append(String(li[mm.upperBound...]))
                    j += 1
                }
                blocks.append(.numberedList(items))
                i = j
                continue
            }

            // Parágrafo ou linha vazia
            if trimmed.isEmpty {
                i += 1
                continue
            }
            blocks.append(.paragraph(trimmed))
            i += 1
        }

        return blocks
    }

    // MARK: - Blocos → Markdown

    static func toMarkdown(_ blocks: [ScriptBlock]) -> String {
        blocks.map { blockToMarkdown($0) }.joined(separator: "\n\n")
    }

    private static func blockToMarkdown(_ b: ScriptBlock) -> String {
        switch b {
        case .paragraph(let text):
            return text
        case .heading(let level, let text):
            return String(repeating: "#", count: level) + " " + text
        case .bulletedList(let items):
            return items.map { "- \($0)" }.joined(separator: "\n")
        case .numberedList(let items):
            return items.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        case .table(let rows):
            guard !rows.isEmpty else { return "| |\n| --- |" }
            let header = "| " + rows[0].map { escapeTableCell($0) }.joined(separator: " | ") + " |"
            let sep = "| " + rows[0].indices.map { _ in "---" }.joined(separator: " | ") + " |"
            let body = rows.dropFirst().map { row in
                "| " + row.map { escapeTableCell($0) }.joined(separator: " | ") + " |"
            }.joined(separator: "\n")
            if body.isEmpty { return header + "\n" + sep }
            return header + "\n" + sep + "\n" + body
        }
    }

    private static func escapeTableCell(_ s: String) -> String {
        s.replacingOccurrences(of: "|", with: "\\|").replacingOccurrences(of: "\n", with: " ")
    }
}
