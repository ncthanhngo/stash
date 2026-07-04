import SwiftUI
import AppKit

/// Single-row recorder for one `HotkeyAction`. Click **Record**, press a combo
/// with at least one of ⌘ / ⌥ / ⌃ — the new combo is saved immediately.
/// Esc cancels. Bare keys produce an inline error rather than silent rejection.
struct HotkeyRecorderRow: View {
    let action: HotkeyAction
    @ObservedObject var bindings: HotkeyBindings

    @State private var recording = false
    @State private var monitor: Any?
    @State private var errorMessage: String?

    private var current: KeyCombo {
        bindings.combo(for: action)
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(action.displayName)
                .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 2) {
                Text(recording ? "Press combo…" : current.display)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(recording ? .secondary : .primary)
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            Button(recording ? "Cancel" : "Record") { toggle() }
            Menu("") {
                Button("Disable") { bindings.disable(action) }
                Button("Reset to default") { bindings.reset(action) }
            }
            .menuStyle(.borderlessButton)
            .frame(width: 16)
        }
        .onDisappear { stop() }
    }

    private func toggle() {
        if recording { stop() } else { start() }
    }

    private func start() {
        recording = true
        errorMessage = nil
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handle(event)
        }
    }

    private func stop() {
        if let m = monitor { NSEvent.removeMonitor(m) }
        monitor = nil
        recording = false
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        // Escape (kVK_Escape = 0x35) cancels recording without changing the combo.
        if event.keyCode == 0x35 {
            stop()
            return nil
        }
        let mods = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting(.capsLock)
        let hasRequiredMod =
            mods.contains(.command) || mods.contains(.option) || mods.contains(.control)
        guard hasRequiredMod else {
            errorMessage = "Need ⌘ / ⌥ / ⌃"
            return nil
        }
        let combo = KeyCombo(
            keyCode: UInt32(event.keyCode),
            modifierFlagsRaw: mods.rawValue,
            keyDisplay: Self.label(for: event)
        )
        do {
            try bindings.update(combo, for: action)
            errorMessage = nil
            stop()
        } catch HotkeyBindings.BindingError.collision(let other) {
            errorMessage = "Already bound to \(other.displayName)"
        } catch {
            errorMessage = "Couldn't save: \(String(describing: error))"
        }
        return nil
    }

    private static func label(for event: NSEvent) -> String {
        if let named = specialKeyName(for: event.keyCode) { return named }
        let raw = (event.charactersIgnoringModifiers ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !raw.isEmpty { return raw.uppercased() }
        return "Key\(event.keyCode)"
    }

    private static func specialKeyName(for code: UInt16) -> String? {
        switch code {
        case 0x24: return "Return"
        case 0x30: return "Tab"
        case 0x31: return "Space"
        case 0x33: return "Delete"
        case 0x7B: return "←"
        case 0x7C: return "→"
        case 0x7D: return "↓"
        case 0x7E: return "↑"
        case 0x7A: return "F1"
        case 0x78: return "F2"
        case 0x63: return "F3"
        case 0x76: return "F4"
        case 0x60: return "F5"
        case 0x61: return "F6"
        case 0x62: return "F7"
        case 0x64: return "F8"
        case 0x65: return "F9"
        case 0x6D: return "F10"
        case 0x67: return "F11"
        case 0x6F: return "F12"
        default: return nil
        }
    }
}
