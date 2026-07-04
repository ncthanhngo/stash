enum HotkeyAction: Hashable {
    case pasteSlot(Int)
    case pasteLatestPlainText
    case togglePopover
    case togglePrivacyMode
    case captureScreenshotCrop

    /// Stable string used as the persistence map key. Never change without
    /// writing a migration — user-customised combos are keyed by this.
    var storageKey: String {
        switch self {
        case .pasteSlot(let n):         return "paste-slot-\(n)"
        case .pasteLatestPlainText:     return "paste-latest-plain"
        case .togglePopover:            return "toggle-popover"
        case .togglePrivacyMode:        return "toggle-pause"
        case .captureScreenshotCrop:    return "screen-crop"
        }
    }

    var displayName: String {
        switch self {
        case .pasteSlot(let n):         return "Paste slot \(n)"
        case .pasteLatestPlainText:     return "Paste most-recent (plain text)"
        case .togglePopover:            return "Toggle popover"
        case .togglePrivacyMode:        return "Toggle pause capture"
        case .captureScreenshotCrop:    return "Screen crop"
        }
    }

    /// Default factory-shipped combo. Backwards-compatible with pre-rebind defaults.
    var defaultCombo: KeyCombo {
        switch self {
        case .pasteSlot(let n):
            return KeyCombo(
                keyCode: Self.numberKeyCodes[n - 1],
                modifierFlagsRaw: KeyCombo.ModifierBits.option,
                keyDisplay: "\(n)"
            )
        case .pasteLatestPlainText:
            return KeyCombo(
                keyCode: 0x09,
                modifierFlagsRaw: KeyCombo.ModifierBits.shift | KeyCombo.ModifierBits.command,
                keyDisplay: "V"
            )
        case .togglePopover:
            return KeyCombo(
                keyCode: 0x08,
                modifierFlagsRaw: KeyCombo.ModifierBits.shift | KeyCombo.ModifierBits.command,
                keyDisplay: "C"
            )
        case .togglePrivacyMode:
            return KeyCombo(
                keyCode: 0x23,
                modifierFlagsRaw: KeyCombo.ModifierBits.shift
                    | KeyCombo.ModifierBits.option
                    | KeyCombo.ModifierBits.command,
                keyDisplay: "P"
            )
        case .captureScreenshotCrop:
            return KeyCombo(
                keyCode: 0x01,
                modifierFlagsRaw: KeyCombo.ModifierBits.shift | KeyCombo.ModifierBits.command,
                keyDisplay: "S"
            )
        }
    }

    /// All actions exposed in the Settings rebind table, in display order.
    static var allCustomisable: [HotkeyAction] {
        (1...9).map { HotkeyAction.pasteSlot($0) } + [
            .pasteLatestPlainText,
            .togglePopover,
            .togglePrivacyMode,
            .captureScreenshotCrop,
        ]
    }

    /// Carbon key codes for digits 1…9 (`kVK_ANSI_1` … `kVK_ANSI_9`).
    private static let numberKeyCodes: [UInt32] = [
        0x12, 0x13, 0x14, 0x15, 0x17, 0x16, 0x1A, 0x1C, 0x19,
    ]
}
