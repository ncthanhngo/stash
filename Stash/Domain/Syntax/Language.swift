import Foundation

enum Language: String, CaseIterable, Equatable, Sendable {
    case plain, swift, javascript, typescript, python, go, rust, bash, json, yaml

    var displayName: String {
        switch self {
        case .plain: return "Plain"
        case .swift: return "Swift"
        case .javascript: return "JavaScript"
        case .typescript: return "TypeScript"
        case .python: return "Python"
        case .go: return "Go"
        case .rust: return "Rust"
        case .bash: return "Bash"
        case .json: return "JSON"
        case .yaml: return "YAML"
        }
    }
}
