import AppKit
import HotKey
import os

final class HotkeyCenter {
    private static let log = Logger(subsystem: "com.soi.clipstash", category: "hotkeys")

    private let handler: (HotkeyAction) -> Void
    private var hotKeys: [HotKey] = []

    init(handler: @escaping (HotkeyAction) -> Void) {
        self.handler = handler
    }

    func registerDefaults() {
        unregisterAll()
        let slotKeys: [Key] = [.one, .two, .three, .four, .five, .six, .seven, .eight, .nine]
        for (index, key) in slotKeys.enumerated() {
            let slot = index + 1
            let hk = HotKey(key: key, modifiers: .option)
            hk.keyDownHandler = { [weak self] in
                self?.handler(.pasteSlot(slot))
            }
            hotKeys.append(hk)
        }

        let plain = HotKey(key: .v, modifiers: [.command, .shift])
        plain.keyDownHandler = { [weak self] in self?.handler(.plainPaste) }
        hotKeys.append(plain)

        let toggle = HotKey(key: .c, modifiers: [.command, .shift])
        toggle.keyDownHandler = { [weak self] in self?.handler(.togglePopover) }
        hotKeys.append(toggle)

        Self.log.info("registered \(self.hotKeys.count, privacy: .public) hotkeys")
    }

    func unregisterAll() {
        hotKeys.removeAll()
    }
}
