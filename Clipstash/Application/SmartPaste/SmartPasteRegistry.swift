import Foundation

final class SmartPasteRegistry {
    private let rules: [SmartPasteRule]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard, rules: [SmartPasteRule]? = nil) {
        self.defaults = defaults
        self.rules = rules ?? [
            TerminalRule(),
            CodeEditorRule(),
            SlackRule()
        ]
    }

    var allRules: [SmartPasteRule] { rules }

    func apply(content: CapturedContent, frontmostBundleID: String?) -> CapturedContent {
        guard let bid = frontmostBundleID else { return content }
        for rule in rules where rule.bundleIDs.contains(bid) && isEnabled(rule) {
            return rule.transform(content)
        }
        return content
    }

    func isEnabled(_ rule: SmartPasteRule) -> Bool {
        defaults.object(forKey: settingsKey(for: rule)) as? Bool ?? true
    }

    func setEnabled(_ rule: SmartPasteRule, enabled: Bool) {
        defaults.set(enabled, forKey: settingsKey(for: rule))
    }

    private func settingsKey(for rule: SmartPasteRule) -> String {
        "clipstash.smartPaste.\(rule.id)"
    }
}
