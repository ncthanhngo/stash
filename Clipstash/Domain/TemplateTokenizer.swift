import Foundation

enum TemplateToken: Equatable {
    case literal(String)
    case variable(name: String, arg: String?)
    case cursor
}

enum TemplateTokenizer {
    static func tokenize(_ template: String) -> [TemplateToken] {
        var tokens: [TemplateToken] = []
        var buffer = ""
        var index = template.startIndex

        while index < template.endIndex {
            let remaining = template[index...]
            if remaining.hasPrefix("$|$") {
                flush(&buffer, into: &tokens)
                tokens.append(.cursor)
                index = template.index(index, offsetBy: 3)
                continue
            }
            if remaining.hasPrefix("{{"),
               let closeRange = template.range(of: "}}", range: index..<template.endIndex)
            {
                let inner = template[template.index(index, offsetBy: 2)..<closeRange.lowerBound]
                let parts = inner.split(separator: ":", maxSplits: 1).map(String.init)
                let name = parts.first ?? ""
                let arg = parts.count > 1 ? parts[1] : nil
                flush(&buffer, into: &tokens)
                tokens.append(.variable(name: name, arg: arg))
                index = closeRange.upperBound
                continue
            }
            buffer.append(template[index])
            index = template.index(after: index)
        }
        flush(&buffer, into: &tokens)
        return demoteExtraCursors(tokens)
    }

    private static func flush(_ buffer: inout String, into tokens: inout [TemplateToken]) {
        if !buffer.isEmpty {
            tokens.append(.literal(buffer))
            buffer = ""
        }
    }

    private static func demoteExtraCursors(_ tokens: [TemplateToken]) -> [TemplateToken] {
        var sawCursor = false
        return tokens.map { token in
            if case .cursor = token {
                if sawCursor { return .literal("$|$") }
                sawCursor = true
            }
            return token
        }
    }
}
