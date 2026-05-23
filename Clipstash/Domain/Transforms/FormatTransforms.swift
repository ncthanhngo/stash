import Foundation

enum FormatTransforms {
    static func apply(_ transform: TextTransform, to input: String) -> Result<String, TransformError> {
        switch transform {
        case .jsonPretty:
            return jsonReformat(input, pretty: true)
        case .jsonMinify:
            return jsonReformat(input, pretty: false)
        default:
            return .failure(.unsupportedOperation)
        }
    }

    private static func jsonReformat(_ input: String, pretty: Bool) -> Result<String, TransformError> {
        guard let data = input.data(using: .utf8) else {
            return .failure(.invalidInput("not UTF-8"))
        }
        do {
            let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            let options: JSONSerialization.WritingOptions = pretty
                ? [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
                : [.withoutEscapingSlashes]
            let output = try JSONSerialization.data(withJSONObject: object, options: options)
            guard let text = String(data: output, encoding: .utf8) else {
                return .failure(.invalidInput("output not utf8"))
            }
            return .success(text)
        } catch {
            return .failure(.invalidInput("invalid JSON: \(error.localizedDescription)"))
        }
    }
}
