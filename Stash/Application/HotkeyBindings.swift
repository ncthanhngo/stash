import Foundation
import Combine

/// All user-customisable hotkey bindings. Persists as JSON `[String: KeyCombo]`
/// under `stash.hotkeys.v1`. Migrates the legacy `stash.hotkey.screenshot`
/// single-binding key into the map on first load.
@MainActor
final class HotkeyBindings: ObservableObject {
    @Published private(set) var bindings: [String: KeyCombo] = [:]

    private let defaults: UserDefaults
    private let storageKey = "stash.hotkeys.v1"
    private let legacyScreenshotKey = "stash.hotkey.screenshot"

    enum BindingError: Error, Equatable {
        case collision(with: HotkeyAction)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.bindings = load()
    }

    /// Current combo for an action (custom override or factory default).
    func combo(for action: HotkeyAction) -> KeyCombo {
        bindings[action.storageKey] ?? action.defaultCombo
    }

    /// Save a custom combo. Throws `.collision` if another action already uses it.
    func update(_ combo: KeyCombo, for action: HotkeyAction) throws {
        if !combo.isDisabled,
           let conflict = collidingAction(combo: combo, excluding: action) {
            throw BindingError.collision(with: conflict)
        }
        bindings[action.storageKey] = combo
        persist()
    }

    /// Restore a single action to its factory default.
    func reset(_ action: HotkeyAction) {
        bindings.removeValue(forKey: action.storageKey)
        persist()
    }

    /// Restore every action to factory defaults.
    func resetAll() {
        bindings.removeAll()
        persist()
    }

    func disable(_ action: HotkeyAction) {
        bindings[action.storageKey] = .disabled
        persist()
    }

    private func collidingAction(combo: KeyCombo, excluding self_: HotkeyAction) -> HotkeyAction? {
        for action in HotkeyAction.allCustomisable where action != self_ {
            let other = self.combo(for: action)
            if !other.isDisabled
                && other.keyCode == combo.keyCode
                && other.modifierFlagsRaw == combo.modifierFlagsRaw {
                return action
            }
        }
        return nil
    }

    private func load() -> [String: KeyCombo] {
        var map: [String: KeyCombo] = [:]

        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([String: KeyCombo].self, from: data) {
            map = decoded
        }

        // One-shot legacy migration: pre-Phase-02 stored only the screen-crop combo.
        if let legacy = defaults.data(forKey: legacyScreenshotKey),
           let combo = try? JSONDecoder().decode(KeyCombo.self, from: legacy) {
            let key = HotkeyAction.captureScreenshotCrop.storageKey
            if map[key] == nil { map[key] = combo }
            defaults.removeObject(forKey: legacyScreenshotKey)
        }

        return map
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(bindings) {
            defaults.set(data, forKey: storageKey)
        }
    }
}
