import Foundation

struct TerminalRule: SmartPasteRule {
    let id = "terminal"
    let displayName = "Terminal — strip ANSI escape codes"
    let bundleIDs: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "dev.warp.Warp-Stable",
        "co.zeit.hyper",
        "io.alacritty"
    ]

    func transform(_ content: CapturedContent) -> CapturedContent {
        guard case .text(let s) = content else { return content }
        return .text(AnsiStripper.strip(s))
    }
}
