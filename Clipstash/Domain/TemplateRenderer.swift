import Foundation

struct RenderContext {
    var date: Date = Date()
    var clipboard: String?
    var uuidProvider: () -> String = { UUID().uuidString }
    var promptAnswers: [String: String] = [:]
}

struct RenderResult: Equatable {
    let text: String
    let cursorOffsetFromEnd: Int
}

enum TemplateRenderer {
    static func render(_ template: String, context: RenderContext = RenderContext()) -> RenderResult {
        let tokens = TemplateTokenizer.tokenize(template)
        var output = ""
        var cursorPos: Int?

        for token in tokens {
            switch token {
            case .literal(let s):
                output += s
            case .variable(let name, let arg):
                output += resolve(name: name, arg: arg, context: context)
            case .cursor:
                cursorPos = output.count
            }
        }

        let offset = cursorPos.map { output.count - $0 } ?? 0
        return RenderResult(text: output, cursorOffsetFromEnd: offset)
    }

    private static func resolve(name: String, arg: String?, context: RenderContext) -> String {
        switch name {
        case "date":
            return format(context.date, pattern: arg ?? "yyyy-MM-dd")
        case "time":
            return format(context.date, pattern: arg ?? "HH:mm")
        case "clipboard":
            return context.clipboard ?? ""
        case "uuid":
            return context.uuidProvider()
        case "prompt":
            return context.promptAnswers[arg ?? ""] ?? ""
        default:
            return arg.map { "{{\(name):\($0)}}" } ?? "{{\(name)}}"
        }
    }

    static func promptLabels(in template: String) -> [String] {
        var labels: [String] = []
        var seen = Set<String>()
        for token in TemplateTokenizer.tokenize(template) {
            if case .variable(let name, let arg) = token, name == "prompt", let label = arg {
                if !seen.contains(label) {
                    seen.insert(label)
                    labels.append(label)
                }
            }
        }
        return labels
    }

    private static func format(_ date: Date, pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}
