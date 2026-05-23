import Foundation

struct LanguageDescriptor {
    let keywords: Set<String>
    let lineComment: String?
    let blockComment: (open: String, close: String)?
    let stringDelimiters: [Character]
}

enum KeywordSets {
    static func descriptor(for language: Language) -> LanguageDescriptor {
        switch language {
        case .swift:
            return LanguageDescriptor(
                keywords: ["func", "let", "var", "if", "else", "guard", "return", "for", "in", "while", "switch", "case", "default", "break", "continue", "import", "class", "struct", "enum", "protocol", "extension", "init", "deinit", "self", "Self", "true", "false", "nil", "throws", "throw", "try", "do", "catch", "async", "await", "actor", "public", "private", "internal", "fileprivate", "open", "static", "final", "lazy", "weak", "unowned", "typealias", "associatedtype", "where"],
                lineComment: "//",
                blockComment: ("/*", "*/"),
                stringDelimiters: ["\""]
            )
        case .javascript, .typescript:
            return LanguageDescriptor(
                keywords: ["function", "const", "let", "var", "if", "else", "for", "while", "return", "break", "continue", "switch", "case", "default", "class", "extends", "import", "export", "from", "async", "await", "try", "catch", "finally", "throw", "new", "this", "super", "true", "false", "null", "undefined", "typeof", "instanceof", "interface", "type", "enum", "public", "private", "protected", "static", "readonly"],
                lineComment: "//",
                blockComment: ("/*", "*/"),
                stringDelimiters: ["\"", "'", "`"]
            )
        case .python:
            return LanguageDescriptor(
                keywords: ["def", "class", "if", "elif", "else", "for", "while", "return", "break", "continue", "import", "from", "as", "try", "except", "finally", "raise", "with", "lambda", "yield", "async", "await", "True", "False", "None", "and", "or", "not", "in", "is", "pass", "global", "nonlocal", "self"],
                lineComment: "#",
                blockComment: nil,
                stringDelimiters: ["\"", "'"]
            )
        case .go:
            return LanguageDescriptor(
                keywords: ["func", "package", "import", "var", "const", "type", "struct", "interface", "if", "else", "for", "range", "return", "break", "continue", "switch", "case", "default", "go", "defer", "chan", "select", "map", "true", "false", "nil"],
                lineComment: "//",
                blockComment: ("/*", "*/"),
                stringDelimiters: ["\"", "`"]
            )
        case .rust:
            return LanguageDescriptor(
                keywords: ["fn", "let", "mut", "if", "else", "for", "while", "loop", "return", "break", "continue", "match", "pub", "use", "mod", "struct", "enum", "trait", "impl", "self", "Self", "true", "false", "as", "ref", "static", "const", "type", "where", "async", "await", "move"],
                lineComment: "//",
                blockComment: ("/*", "*/"),
                stringDelimiters: ["\""]
            )
        case .bash:
            return LanguageDescriptor(
                keywords: ["if", "then", "else", "elif", "fi", "for", "while", "do", "done", "case", "esac", "function", "return", "echo", "export", "local", "readonly", "set", "unset", "true", "false"],
                lineComment: "#",
                blockComment: nil,
                stringDelimiters: ["\"", "'"]
            )
        case .json:
            return LanguageDescriptor(
                keywords: ["true", "false", "null"],
                lineComment: nil,
                blockComment: nil,
                stringDelimiters: ["\""]
            )
        case .yaml:
            return LanguageDescriptor(
                keywords: ["true", "false", "null", "yes", "no"],
                lineComment: "#",
                blockComment: nil,
                stringDelimiters: ["\"", "'"]
            )
        case .plain:
            return LanguageDescriptor(
                keywords: [],
                lineComment: nil,
                blockComment: nil,
                stringDelimiters: []
            )
        }
    }
}
