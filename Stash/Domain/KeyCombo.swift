import Foundation

/// User-configurable keyboard shortcut. Stored as raw integers so Domain stays
/// free of AppKit; the composition root maps to `NSEvent.ModifierFlags` and
/// HotKey's `Key` when registering.
struct KeyCombo: Equatable, Codable {
    /// Carbon virtual key code (same value as `NSEvent.keyCode`, widened to UInt32).
    let keyCode: UInt32

    /// Raw value of `NSEvent.ModifierFlags & .deviceIndependentFlagsMask`.
    let modifierFlagsRaw: UInt

    /// Human-readable key label captured at record time (e.g. `"S"`, `"F1"`, `"Space"`).
    let keyDisplay: String

    /// Sentinel for "user explicitly disabled this hotkey". HotkeyCenter skips
    /// registration. `keyCode == 0 && modifierFlagsRaw == 0` is unreachable
    /// from the recorder (bare keys are rejected; modifier-only combos are
    /// rejected) so it's safe to reserve.
    static let disabled = KeyCombo(keyCode: 0, modifierFlagsRaw: 0, keyDisplay: "—")

    var isDisabled: Bool {
        keyCode == 0 && modifierFlagsRaw == 0
    }

    /// Bit positions copied from `NSEvent.ModifierFlags` — stable since 10.0.
    enum ModifierBits {
        static let shift:   UInt = 1 << 17
        static let control: UInt = 1 << 18
        static let option:  UInt = 1 << 19
        static let command: UInt = 1 << 20
    }

    var display: String {
        if isDisabled { return "Disabled" }
        var out = ""
        if modifierFlagsRaw & ModifierBits.control != 0 { out += "⌃" }
        if modifierFlagsRaw & ModifierBits.option  != 0 { out += "⌥" }
        if modifierFlagsRaw & ModifierBits.shift   != 0 { out += "⇧" }
        if modifierFlagsRaw & ModifierBits.command != 0 { out += "⌘" }
        out += keyDisplay
        return out
    }
}
