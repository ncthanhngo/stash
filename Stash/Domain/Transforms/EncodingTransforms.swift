import Foundation

enum EncodingTransforms {
    static func apply(_ transform: TextTransform, to input: String) -> Result<String, TransformError> {
        switch transform {
        case .urlEncode:
            return .success(input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? input)
        case .urlDecode:
            return .success(input.removingPercentEncoding ?? input)
        case .base64Encode:
            return .success(Data(input.utf8).base64EncodedString())
        case .base64Decode:
            guard let data = Data(base64Encoded: input),
                  let text = String(data: data, encoding: .utf8)
            else { return .failure(.invalidInput("not valid base64 utf8")) }
            return .success(text)
        case .htmlEncode:
            return .success(htmlEncode(input))
        case .htmlDecode:
            return .success(htmlDecode(input))
        case .unescapeJSString:
            return .success(unescapeJSString(input))
        default:
            return .failure(.unsupportedOperation)
        }
    }

    private static func htmlEncode(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        for ch in s {
            switch ch {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            case "'": out += "&#39;"
            default: out.append(ch)
            }
        }
        return out
    }

    private static func htmlDecode(_ s: String) -> String {
        var out = s
        let pairs: [(String, String)] = [
            ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
            ("&quot;", "\""), ("&#39;", "'"), ("&nbsp;", " ")
        ]
        for (entity, char) in pairs {
            out = out.replacingOccurrences(of: entity, with: char)
        }
        return out
    }

    private static func unescapeJSString(_ s: String) -> String {
        var out = s
        out = out.replacingOccurrences(of: "\\n", with: "\n")
        out = out.replacingOccurrences(of: "\\t", with: "\t")
        out = out.replacingOccurrences(of: "\\r", with: "\r")
        out = out.replacingOccurrences(of: "\\\"", with: "\"")
        out = out.replacingOccurrences(of: "\\'", with: "'")
        out = out.replacingOccurrences(of: "\\\\", with: "\\")
        return out
    }
}
