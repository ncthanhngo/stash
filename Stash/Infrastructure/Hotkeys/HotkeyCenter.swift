import AppKit
import HotKey
import os

@MainActor
final class HotkeyCenter {
    private static let log = Logger(subsystem: "com.soi.stash", category: "hotkeys")

    private let handler: (HotkeyAction) -> Void
    private var hotKeys: [HotkeyAction: HotKey] = [:]
    private(set) var failedToRegister: Set<HotkeyAction> = []

    init(handler: @escaping (HotkeyAction) -> Void) {
        self.handler = handler
    }

    /// Re-register every customisable hotkey from the current bindings.
    /// Safe to call repeatedly when the user edits a combo in Settings.
    func apply(_ bindings: HotkeyBindings) {
        unregisterAll()
        for action in HotkeyAction.allCustomisable {
            register(action, combo: bindings.combo(for: action))
        }
        Self.log.info("registered \(self.hotKeys.count, privacy: .public) hotkeys; failed=\(self.failedToRegister.count, privacy: .public)")
    }

    func unregisterAll() {
        hotKeys.removeAll()
        failedToRegister.removeAll()
    }

    private func register(_ action: HotkeyAction, combo: KeyCombo) {
        guard !combo.isDisabled else { return }
        guard let key = Key(carbonKeyCode: combo.keyCode) else {
            Self.log.error("invalid carbon keyCode=\(combo.keyCode, privacy: .public) for \(action.storageKey, privacy: .public)")
            failedToRegister.insert(action)
            return
        }
        let mods = NSEvent.ModifierFlags(rawValue: combo.modifierFlagsRaw)
        let hk = HotKey(key: key, modifiers: mods)
        hk.keyDownHandler = { [weak self] in self?.handler(action) }
        hotKeys[action] = hk
    }
}
