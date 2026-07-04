import Foundation

protocol PasteEngine: AnyObject {
    func paste(_ item: ClipboardItem, mode: PasteMode) throws
    func pasteRenderedTemplate(_ template: String, promptAnswers: [String: String]) throws
}

enum PasteMode: Equatable {
    case normal
    case plainText
}

enum PasteError: Error, Equatable {
    case accessibilityDenied
    case eventCreationFailed
    /// macOS Secure Event Input is on (password field focused). Synthetic
    /// keystrokes are dropped by the kernel; content is on the pasteboard so
    /// the user can press ⌘V manually.
    case secureInputActive
    /// Accessibility was granted previously but revoked since launch. Same UX
    /// as `accessibilityDenied` but distinguished for diagnostics + messaging.
    case accessibilityRevoked
    /// Stash itself is the frontmost app when paste fires — the synthetic ⌘V
    /// would land back on the popover/Settings window. Caller should retry
    /// after the focus shifts.
    case frontmostIsSelf
}
