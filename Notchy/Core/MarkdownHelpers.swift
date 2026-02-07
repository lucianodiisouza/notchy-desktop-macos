import Foundation

/// Helpers for Markdown in scripts: strip to plain text (e.g. for teleprompter) and format insertion.
enum MarkdownHelpers {

    /// Converts Markdown to plain text for display in the teleprompter (no formatting).
    static func plainText(from markdown: String) -> String {
        var s = markdown
        // Code blocks (preserve content, strip fences)
        let codeBlockPattern = "```[^`]*\\n([\\s\\S]*?)```"
        if let regex = try? NSRegularExpression(pattern: codeBlockPattern) {
            let range = NSRange(s.startIndex..., in: s)
            s = regex.stringByReplacingMatches(in: s, range: range, withTemplate: "$1")
        }
        // Inline code e riscado (compatibilidade com conteúdo antigo)
        if let regex = try? NSRegularExpression(pattern: "`([^`]+)`") {
            let range = NSRange(s.startIndex..., in: s)
            s = regex.stringByReplacingMatches(in: s, range: range, withTemplate: "$1")
        }
        if let regex = try? NSRegularExpression(pattern: "~~([^~]+)~~") {
            let range = NSRange(s.startIndex..., in: s)
            s = regex.stringByReplacingMatches(in: s, range: range, withTemplate: "$1")
        }
        // Links: [text](url) -> text
        if let regex = try? NSRegularExpression(pattern: "\\[([^\\]]+)\\]\\([^)]*\\)") {
            let range = NSRange(s.startIndex..., in: s)
            s = regex.stringByReplacingMatches(in: s, range: range, withTemplate: "$1")
        }
        // Headings: ### text -> text
        if let regex = try? NSRegularExpression(pattern: "^#{1,6}\\s+", options: .anchorsMatchLines) {
            let range = NSRange(s.startIndex..., in: s)
            s = regex.stringByReplacingMatches(in: s, range: range, withTemplate: "")
        }
        // Bold ** or __; underline %
        s = s.replacingOccurrences(of: "**", with: "")
        s = s.replacingOccurrences(of: "__", with: "")
        if let regex = try? NSRegularExpression(pattern: "%([^%]+)%") {
            let range = NSRange(s.startIndex..., in: s)
            s = regex.stringByReplacingMatches(in: s, range: range, withTemplate: "$1")
        }
        // Tamanho [N]...[/N]
        if let regex = try? NSRegularExpression(pattern: "\\[(\\d+)\\]([\\s\\S]*?)\\[/\\1\\]") {
            let range = NSRange(s.startIndex..., in: s)
            s = regex.stringByReplacingMatches(in: s, range: range, withTemplate: "$2")
        }
        // Italic * or _ (single; be careful not to break mid-word underscores)
        if let regex = try? NSRegularExpression(pattern: "(?<![*_])\\*([^*]+)\\*(?![*_])") {
            let range = NSRange(s.startIndex..., in: s)
            s = regex.stringByReplacingMatches(in: s, range: range, withTemplate: "$1")
        }
        if let regex = try? NSRegularExpression(pattern: "(?<![_*])_([^_]+)_(?![_*])") {
            let range = NSRange(s.startIndex..., in: s)
            s = regex.stringByReplacingMatches(in: s, range: range, withTemplate: "$1")
        }
        // List markers at line start
        if let regex = try? NSRegularExpression(pattern: "^(\\s*)[-*+]\\s+", options: .anchorsMatchLines) {
            let range = NSRange(s.startIndex..., in: s)
            s = regex.stringByReplacingMatches(in: s, range: range, withTemplate: "$1")
        }
        if let regex = try? NSRegularExpression(pattern: "^(\\s*)\\d+\\.\\s+", options: .anchorsMatchLines) {
            let range = NSRange(s.startIndex..., in: s)
            s = regex.stringByReplacingMatches(in: s, range: range, withTemplate: "$1")
        }
        // Blockquote
        if let regex = try? NSRegularExpression(pattern: "^>\\s*", options: .anchorsMatchLines) {
            let range = NSRange(s.startIndex..., in: s)
            s = regex.stringByReplacingMatches(in: s, range: range, withTemplate: "")
        }
        // Tables: convert to plain lines (| a | b | -> "a b"; separator line |---|---| -> remove)
        s = plainTextFromMarkdownTables(s)
        // Horizontal rule (---, ***, ___)
        if let regex = try? NSRegularExpression(pattern: "^(?:[-*_]{2,})\\s*$", options: .anchorsMatchLines) {
            let range = NSRange(s.startIndex..., in: s)
            s = regex.stringByReplacingMatches(in: s, range: range, withTemplate: "")
        }
        // Collapse multiple newlines to max 2
        if let regex = try? NSRegularExpression(pattern: "\\n{3,}") {
            let range = NSRange(s.startIndex..., in: s)
            s = regex.stringByReplacingMatches(in: s, range: range, withTemplate: "\n\n")
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Converts Markdown table rows to plain text: cells separated by spaces, one line per row.
    /// Separator lines (|---|---|) are removed.
    private static func plainTextFromMarkdownTables(_ s: String) -> String {
        let lines = s.components(separatedBy: .newlines)
        var result: [String] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Skip table separator line (e.g. |---|---| or |:---|:---:|---:|)
            if let sepRegex = try? NSRegularExpression(pattern: "^\\|?[-:\\s]+(\\|[-:\\s]+)*\\|?\\s*$"),
               sepRegex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil {
                continue
            }
            // Table row: | cell1 | cell2 | -> "cell1 cell2"
            if trimmed.contains("|") {
                let cells = trimmed
                    .split(separator: "|", omittingEmptySubsequences: false)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                if !cells.isEmpty {
                    result.append(cells.joined(separator: " "))
                    continue
                }
            }
            result.append(line)
        }
        return result.joined(separator: "\n")
    }

    // MARK: - Markdown to HTML (para preview com tabelas)

    /// Converts Markdown to HTML for preview (headings, bold, italic, lists, tables).
    static func markdownToHTML(_ markdown: String) -> String {
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0) }
        var i = 0
        var blocks: [String] = []

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Table: consecutive lines with | (header, optional separator, body rows)
            if trimmed.contains("|") {
                var tableRows: [[String]] = []
                var j = i
                while j < lines.count, lines[j].trimmingCharacters(in: .whitespaces).contains("|") {
                    let row = lines[j]
                        .split(separator: "|", omittingEmptySubsequences: false)
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                    if row.isEmpty { break }
                    // Skip separator line (only ---, :---, etc.)
                    let isSeparator = row.allSatisfy { cell in
                        cell.trimmingCharacters(in: .whitespaces).allSatisfy { $0 == "-" || $0 == ":" || $0 == " " }
                    }
                    if !isSeparator {
                        tableRows.append(row.map { applyInlineMarkdown(escapeHTML($0)) })
                    }
                    j += 1
                }
                if !tableRows.isEmpty {
                    var tableHtml = "<table class=\"md-table\">"
                    tableRows.enumerated().forEach { idx, row in
                        let tag = idx == 0 ? "th" : "td"
                        tableHtml += "<tr>"
                        row.forEach { cell in tableHtml += "<\(tag)>\(cell)</\(tag)>" }
                        tableHtml += "</tr>"
                    }
                    tableHtml += "</table>"
                    blocks.append(tableHtml)
                    i = j
                    continue
                }
            }

            // Headings # to ######
            if let headingMatch = trimmed.range(of: "^#{1,6}\\s+", options: .regularExpression) {
                let level = trimmed[trimmed.startIndex..<headingMatch.upperBound]
                    .filter { $0 == "#" }.count
                let content = String(trimmed[headingMatch.upperBound...])
                blocks.append("<h\(min(level, 6))>\(applyInlineMarkdown(escapeHTML(content)))</h\(min(level, 6))>")
                i += 1
                continue
            }

            // Unordered list
            if trimmed.range(of: "^(?:[-*+])\\s+", options: .regularExpression) != nil {
                var listItems: [String] = []
                var j = i
                while j < lines.count {
                    let liLine = lines[j].trimmingCharacters(in: .whitespaces)
                    guard let m = liLine.range(of: "^(?:[-*+])\\s+", options: .regularExpression) else { break }
                    listItems.append(applyInlineMarkdown(escapeHTML(String(liLine[m.upperBound...]))))
                    j += 1
                }
                blocks.append("<ul>" + listItems.map { "<li>\($0)</li>" }.joined() + "</ul>")
                i = j
                continue
            }

            // Ordered list
            if trimmed.range(of: "^\\d+\\.\\s+", options: .regularExpression) != nil {
                var listItems: [String] = []
                var j = i
                while j < lines.count {
                    let liLine = lines[j].trimmingCharacters(in: .whitespaces)
                    guard let m = liLine.range(of: "^\\d+\\.\\s+", options: .regularExpression) else { break }
                    listItems.append(applyInlineMarkdown(escapeHTML(String(liLine[m.upperBound...]))))
                    j += 1
                }
                blocks.append("<ol>" + listItems.map { "<li>\($0)</li>" }.joined() + "</ol>")
                i = j
                continue
            }

            // Paragraph (or empty line)
            if trimmed.isEmpty {
                blocks.append("<br>")
            } else {
                blocks.append("<p>\(applyInlineMarkdown(escapeHTML(trimmed)))</p>")
            }
            i += 1
        }

        return blocks.joined(separator: "\n")
    }

    private static func escapeHTML(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func applyInlineMarkdown(_ s: String) -> String {
        var r = s
        // Tamanho [N]...[/N] -> <span style="font-size:Npx">...</span>
        if let regex = try? NSRegularExpression(pattern: "\\[(\\d+)\\]([\\s\\S]*?)\\[/\\1\\]") {
            let mutable = NSMutableString(string: r)
            regex.replaceMatches(in: mutable, range: NSRange(r.startIndex..., in: r), withTemplate: "<span style=\"font-size:$1px\">$2</span>")
            r = String(mutable)
        }
        // Underline %...%
        if let regex = try? NSRegularExpression(pattern: "%([^%]+)%") {
            let mutable = NSMutableString(string: r)
            regex.replaceMatches(in: mutable, range: NSRange(r.startIndex..., in: r), withTemplate: "<u>$1</u>")
            r = String(mutable)
        }
        // Bold **
        if let regex = try? NSRegularExpression(pattern: "\\*\\*([^*]+)\\*\\*") {
            let mutable = NSMutableString(string: r)
            regex.replaceMatches(in: mutable, range: NSRange(r.startIndex..., in: r), withTemplate: "<strong>$1</strong>")
            r = String(mutable)
        }
        // Bold __
        if let regex = try? NSRegularExpression(pattern: "__([^_]+)__") {
            let mutable = NSMutableString(string: r)
            regex.replaceMatches(in: mutable, range: NSRange(r.startIndex..., in: r), withTemplate: "<strong>$1</strong>")
            r = String(mutable)
        }
        // Italic *
        if let regex = try? NSRegularExpression(pattern: "(?<![*])\\*([^*]+)\\*(?![*])") {
            let mutable = NSMutableString(string: r)
            regex.replaceMatches(in: mutable, range: NSRange(r.startIndex..., in: r), withTemplate: "<em>$1</em>")
            r = String(mutable)
        }
        // Italic _
        if let regex = try? NSRegularExpression(pattern: "(?<![_])_([^_]+)_(?![_])") {
            let mutable = NSMutableString(string: r)
            regex.replaceMatches(in: mutable, range: NSRange(r.startIndex..., in: r), withTemplate: "<em>$1</em>")
            r = String(mutable)
        }
        return r
    }
}
