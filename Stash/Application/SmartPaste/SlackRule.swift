import Foundation

struct SlackRule: SmartPasteRule {
    let id = "slack"
    let displayName = "Slack — Markdown bold to mrkdwn"
    let bundleIDs: Set<String> = [
        "com.tinyspeck.slackmacgap"
    ]

    func transform(_ content: CapturedContent) -> CapturedContent {
        guard case .text(let s) = content else { return content }
        return .text(MarkdownToMrkdwn.convert(s))
    }
}
