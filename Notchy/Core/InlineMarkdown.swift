import Foundation
import AppKit

/// Converte markdown inline (** * %) para NSAttributedString (negrito, itálico, sublinhado).
/// Sem lib externa; usado para live preview e editor rico.
enum InlineMarkdown {

    // MARK: - Markdown → NSAttributedString (AppKit)

    static func attributedString(
        from markdown: String,
        font: NSFont? = .systemFont(ofSize: NSFont.systemFontSize),
        color: NSColor = .labelColor
    ) -> NSAttributedString {
        let baseFont = font ?? .systemFont(ofSize: NSFont.systemFontSize)
        let result = NSMutableAttributedString()
        var remaining = markdown[...]
        while !remaining.isEmpty {
            // Ordem: ** (bold), __ (bold), % (underline), [N] (tamanho), * (italic), _ (italic)
            if remaining.hasPrefix("**"), let end = findClosingBold(remaining) {
                let inner = String(remaining[remaining.index(remaining.startIndex, offsetBy: 2)..<remaining.index(end, offsetBy: -2)])
                let boldFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
                let att = NSAttributedString(string: inner, attributes: [.font: boldFont, .foregroundColor: color])
                result.append(att)
                remaining = remaining[end...]
                continue
            }
            if remaining.hasPrefix("__"), let end = findClosingDoubleUnderscore(remaining) {
                let inner = String(remaining[remaining.index(remaining.startIndex, offsetBy: 2)..<remaining.index(end, offsetBy: -2)])
                let boldFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
                let att = NSAttributedString(string: inner, attributes: [.font: boldFont, .foregroundColor: color])
                result.append(att)
                remaining = remaining[end...]
                continue
            }
            if remaining.hasPrefix("%"), let end = remaining.dropFirst(1).firstIndex(of: "%").map({ remaining.index($0, offsetBy: 1) }) {
                let inner = String(remaining[remaining.index(remaining.startIndex, offsetBy: 1)..<remaining.index(end, offsetBy: -1)])
                let att = NSAttributedString(string: inner, attributes: [
                    .font: baseFont,
                    .foregroundColor: color,
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ])
                result.append(att)
                remaining = remaining[end...]
                continue
            }
            if remaining.hasPrefix("["), let (innerStart, innerEnd, totalEnd, size) = findClosingSizeTag(remaining) {
                let inner = String(remaining[innerStart..<innerEnd])
                let sizeFont = NSFont(descriptor: baseFont.fontDescriptor, size: CGFloat(size)) ?? baseFont
                result.append(attributedString(from: inner, font: sizeFont, color: color))
                remaining = remaining[totalEnd...]
                continue
            }
            if remaining.hasPrefix("*"), !remaining.dropFirst(1).hasPrefix("*"), let end = findClosingItalicStar(remaining) {
                let inner = String(remaining[remaining.index(remaining.startIndex, offsetBy: 1)..<remaining.index(end, offsetBy: -1)])
                let italicFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
                let att = NSAttributedString(string: inner, attributes: [.font: italicFont, .foregroundColor: color])
                result.append(att)
                remaining = remaining[end...]
                continue
            }
            if remaining.hasPrefix("_"), !remaining.dropFirst(1).hasPrefix("_"), let end = findClosingItalicUnderscore(remaining) {
                let inner = String(remaining[remaining.index(remaining.startIndex, offsetBy: 1)..<remaining.index(end, offsetBy: -1)])
                let italicFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
                let att = NSAttributedString(string: inner, attributes: [.font: italicFont, .foregroundColor: color])
                result.append(att)
                remaining = remaining[end...]
                continue
            }
            let next = nextInlineMarkdown(remaining)
            let plain = String(remaining[..<next])
            result.append(NSAttributedString(string: plain, attributes: [.font: baseFont, .foregroundColor: color]))
            remaining = remaining[remaining.index(remaining.startIndex, offsetBy: plain.count)...]
        }
        return result
    }

    private static func findClosingBold(_ s: Substring) -> String.Index? {
        var i = s.index(s.startIndex, offsetBy: 2)
        while i < s.endIndex {
            if s[i] == "*", i != s.endIndex, s.index(after: i) < s.endIndex, s[s.index(after: i)] == "*" {
                return s.index(i, offsetBy: 2)
            }
            i = s.index(after: i)
        }
        return nil
    }

    private static func findClosingDoubleUnderscore(_ s: Substring) -> String.Index? {
        var i = s.index(s.startIndex, offsetBy: 2)
        while i < s.endIndex {
            if s[i] == "_", s.index(after: i) < s.endIndex, s[s.index(after: i)] == "_" {
                return s.index(i, offsetBy: 2)
            }
            i = s.index(after: i)
        }
        return nil
    }

    private static func findClosingItalicStar(_ s: Substring) -> String.Index? {
        var i = s.index(s.startIndex, offsetBy: 1)
        while i < s.endIndex {
            if s[i] == "*" { return s.index(after: i) }
            i = s.index(after: i)
        }
        return nil
    }

    private static func findClosingItalicUnderscore(_ s: Substring) -> String.Index? {
        var i = s.index(s.startIndex, offsetBy: 1)
        while i < s.endIndex {
            if s[i] == "_" { return s.index(after: i) }
            i = s.index(after: i)
        }
        return nil
    }

    /// Retorna (innerStart, innerEnd, totalEnd, size) para [N]...[/N] ou nil.
    private static func findClosingSizeTag(_ s: Substring) -> (innerStart: Substring.Index, innerEnd: Substring.Index, totalEnd: Substring.Index, size: Int)? {
        guard s.hasPrefix("["), s.count >= 2 else { return nil }
        var i = s.index(s.startIndex, offsetBy: 1)
        var numStr = ""
        while i < s.endIndex, s[i].isNumber {
            numStr.append(s[i])
            i = s.index(after: i)
        }
        guard !numStr.isEmpty, i < s.endIndex, s[i] == "]" else { return nil }
        guard let size = Int(numStr), size >= 1, size <= 999 else { return nil }
        let innerStart = s.index(after: i)
        let closeTag = "[/" + numStr + "]"
        guard let closeRange = s[innerStart...].range(of: closeTag) else { return nil }
        return (innerStart, closeRange.lowerBound, closeRange.upperBound, size)
    }

    private static func nextInlineMarkdown(_ s: Substring) -> String.Index {
        var i = s.startIndex
        let markers: [Character] = ["*", "_", "%", "["]
        while i < s.endIndex {
            if markers.contains(s[i]) { return i }
            i = s.index(after: i)
        }
        return s.endIndex
    }

    // MARK: - NSAttributedString → Markdown (ao salvar)

    static func markdown(from attributed: NSAttributedString, baseFont: NSFont?) -> String {
        let str = attributed.string
        guard !str.isEmpty else { return "" }
        let result = NSMutableString()
        let fullRange = NSRange(location: 0, length: attributed.length)
        let baseSize = baseFont?.pointSize ?? NSFont.systemFontSize
        attributed.enumerateAttributes(in: fullRange) { attrs, range, _ in
            let substring = (attributed.string as NSString).substring(with: range)
            let font = (attrs[.font] as? NSFont) ?? baseFont ?? .systemFont(ofSize: NSFont.systemFontSize)
            let traits = font.fontDescriptor.symbolicTraits
            let bold = traits.contains(.bold)
            let italic = traits.contains(.italic)
            let underline = (attrs[.underlineStyle] as? Int) == NSUnderlineStyle.single.rawValue
            let size = Int(round(font.pointSize))
            let customSize = size != Int(round(baseSize)) && size >= 1 && size <= 999
            if customSize { result.append("[\(size)]") }
            if bold { result.append("**") }
            if italic { result.append("*") }
            if underline { result.append("%") }
            result.append(substring)
            if underline { result.append("%") }
            if italic { result.append("*") }
            if bold { result.append("**") }
            if customSize { result.append("[/\(size)]") }
        }
        return String(result)
    }
}
