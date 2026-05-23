import Foundation

struct CodeEditorRule: SmartPasteRule {
    let id = "code-editor"
    let displayName = "Code editor — uniform-dedent leading whitespace"
    let bundleIDs: Set<String> = [
        "com.microsoft.VSCode",
        "com.todesktop.230313mzl4w4u92",   // Cursor
        "com.apple.dt.Xcode",
        "com.sublimetext.4",
        "com.sublimetext.3",
        "com.jetbrains.intellij",
        "com.jetbrains.pycharm",
        "com.jetbrains.WebStorm",
        "com.jetbrains.GoLand",
        "com.jetbrains.RubyMine",
        "com.jetbrains.AppCode"
    ]

    func transform(_ content: CapturedContent) -> CapturedContent {
        guard case .text(let s) = content else { return content }
        return .text(UniformDedent.dedent(s))
    }
}
