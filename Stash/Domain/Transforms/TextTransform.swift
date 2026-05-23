import Foundation

enum TransformError: Error, Equatable {
    case invalidInput(String)
    case unsupportedOperation

    var message: String {
        switch self {
        case .invalidInput(let reason): return reason
        case .unsupportedOperation: return "unsupported"
        }
    }
}

enum TextTransform: String, CaseIterable, Identifiable {
    case urlEncode, urlDecode
    case base64Encode, base64Decode
    case jsonPretty, jsonMinify
    case camelCase, snakeCase, kebabCase
    case md5, sha1, sha256, sha512
    case htmlEncode, htmlDecode
    case trim, unescapeJSString
    case uppercase, lowercase, titleCase
    case reverse

    var id: String { rawValue }

    var category: TransformCategory {
        switch self {
        case .urlEncode, .urlDecode, .base64Encode, .base64Decode,
             .htmlEncode, .htmlDecode, .unescapeJSString:
            return .encoding
        case .md5, .sha1, .sha256, .sha512:
            return .hash
        case .camelCase, .snakeCase, .kebabCase, .uppercase, .lowercase, .titleCase, .reverse:
            return .caseChange
        case .jsonPretty, .jsonMinify:
            return .format
        case .trim:
            return .whitespace
        }
    }

    var displayName: String {
        switch self {
        case .urlEncode: return "URL encode"
        case .urlDecode: return "URL decode"
        case .base64Encode: return "Base64 encode"
        case .base64Decode: return "Base64 decode"
        case .jsonPretty: return "JSON pretty"
        case .jsonMinify: return "JSON minify"
        case .camelCase: return "camelCase"
        case .snakeCase: return "snake_case"
        case .kebabCase: return "kebab-case"
        case .md5: return "MD5"
        case .sha1: return "SHA-1"
        case .sha256: return "SHA-256"
        case .sha512: return "SHA-512"
        case .htmlEncode: return "HTML encode"
        case .htmlDecode: return "HTML decode"
        case .trim: return "Trim whitespace"
        case .unescapeJSString: return "Unescape JS string"
        case .uppercase: return "UPPERCASE"
        case .lowercase: return "lowercase"
        case .titleCase: return "Title Case"
        case .reverse: return "Reverse"
        }
    }

    func apply(_ input: String) -> Result<String, TransformError> {
        switch category {
        case .encoding: return EncodingTransforms.apply(self, to: input)
        case .hash: return HashTransforms.apply(self, to: input)
        case .caseChange: return CaseTransforms.apply(self, to: input)
        case .format: return FormatTransforms.apply(self, to: input)
        case .whitespace: return .success(input.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}

enum TransformCategory: String, CaseIterable {
    case encoding, hash, caseChange, format, whitespace

    var displayName: String {
        switch self {
        case .encoding: return "Encoding"
        case .hash: return "Hash"
        case .caseChange: return "Case"
        case .format: return "Format"
        case .whitespace: return "Whitespace"
        }
    }
}
