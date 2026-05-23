import Foundation
import SwiftUI

enum SyntaxToken {
    case plain, keyword, string, comment, number
}

enum SyntaxHighlighter {
    /// Tokenizes the input text using the language descriptor and returns
    /// an AttributedString suitable for SwiftUI `Text` rendering.
    static func highlight(_ text: String, language: Language) -> AttributedString {
        let descriptor = KeywordSets.descriptor(for: language)
        var result = AttributedString(text)
        let chars = Array(text)
        guard !chars.isEmpty else { return result }

        var i = 0
        while i < chars.count {
            let ch = chars[i]

            if let lineComment = descriptor.lineComment, matchAt(chars, i, lineComment) {
                let start = i
                while i < chars.count && chars[i] != "\n" { i += 1 }
                applyAttribute(.comment, to: &result, in: text, range: start..<i)
                continue
            }
            if let block = descriptor.blockComment, matchAt(chars, i, block.open) {
                let start = i
                i += block.open.count
                while i < chars.count && !matchAt(chars, i, block.close) { i += 1 }
                if i < chars.count { i += block.close.count }
                applyAttribute(.comment, to: &result, in: text, range: start..<i)
                continue
            }
            if descriptor.stringDelimiters.contains(ch) {
                let delim = ch
                let start = i
                i += 1
                while i < chars.count && chars[i] != delim {
                    if chars[i] == "\\" && i + 1 < chars.count { i += 2 } else { i += 1 }
                }
                if i < chars.count { i += 1 }
                applyAttribute(.string, to: &result, in: text, range: start..<i)
                continue
            }
            if ch.isNumber {
                let start = i
                while i < chars.count && (chars[i].isNumber || chars[i] == ".") { i += 1 }
                applyAttribute(.number, to: &result, in: text, range: start..<i)
                continue
            }
            if ch.isLetter || ch == "_" {
                let start = i
                while i < chars.count && (chars[i].isLetter || chars[i].isNumber || chars[i] == "_") {
                    i += 1
                }
                let word = String(chars[start..<i])
                if descriptor.keywords.contains(word) {
                    applyAttribute(.keyword, to: &result, in: text, range: start..<i)
                }
                continue
            }
            i += 1
        }
        return result
    }

    private static func matchAt(_ chars: [Character], _ i: Int, _ s: String) -> Bool {
        guard i + s.count <= chars.count else { return false }
        return String(chars[i..<i + s.count]) == s
    }

    private static func applyAttribute(
        _ token: SyntaxToken,
        to result: inout AttributedString,
        in source: String,
        range: Range<Int>
    ) {
        let startIndex = source.index(source.startIndex, offsetBy: range.lowerBound)
        let endIndex = source.index(source.startIndex, offsetBy: range.upperBound)
        let stringRange = startIndex..<endIndex
        guard let attrRange = Range(stringRange, in: result) else { return }
        switch token {
        case .keyword:
            result[attrRange].foregroundColor = .purple
            result[attrRange].inlinePresentationIntent = .stronglyEmphasized
        case .string:
            result[attrRange].foregroundColor = .green
        case .comment:
            result[attrRange].foregroundColor = .secondary
            result[attrRange].inlinePresentationIntent = .emphasized
        case .number:
            result[attrRange].foregroundColor = .orange
        case .plain:
            break
        }
    }
}
