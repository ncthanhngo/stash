import Foundation

enum CaseTransforms {
    static func apply(_ transform: TextTransform, to input: String) -> Result<String, TransformError> {
        switch transform {
        case .camelCase:
            return .success(toCamelCase(input))
        case .snakeCase:
            return .success(tokenize(input).map { $0.lowercased() }.joined(separator: "_"))
        case .kebabCase:
            return .success(tokenize(input).map { $0.lowercased() }.joined(separator: "-"))
        case .uppercase:
            return .success(input.uppercased())
        case .lowercase:
            return .success(input.lowercased())
        case .titleCase:
            return .success(input.capitalized)
        case .reverse:
            return .success(String(input.reversed()))
        default:
            return .failure(.unsupportedOperation)
        }
    }

    /// Splits "hello_world helloWorld hello-world HELLO" into ["hello","world","hello","World","hello","world","HELLO"]
    private static func tokenize(_ s: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var prev: Character?
        for ch in s {
            if ch == "_" || ch == "-" || ch == " " {
                if !current.isEmpty { tokens.append(current); current = "" }
            } else if let p = prev, p.isLowercase, ch.isUppercase {
                if !current.isEmpty { tokens.append(current); current = "" }
                current.append(ch)
            } else {
                current.append(ch)
            }
            prev = ch
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    private static func toCamelCase(_ s: String) -> String {
        let tokens = tokenize(s).map { $0.lowercased() }
        guard let first = tokens.first else { return "" }
        let rest = tokens.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }
        return first + rest.joined()
    }
}
