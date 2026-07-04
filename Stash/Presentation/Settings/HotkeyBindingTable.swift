import SwiftUI

/// Lists every customisable hotkey. Slots collapse into a disclosure group so
/// the table stays scannable.
struct HotkeyBindingTable: View {
    @ObservedObject var bindings: HotkeyBindings

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            DisclosureGroup("Paste slot 1–9") {
                VStack(spacing: 4) {
                    ForEach(1...9, id: \.self) { n in
                        HotkeyRecorderRow(action: .pasteSlot(n), bindings: bindings)
                    }
                }
                .padding(.top, 4)
            }
            Divider().padding(.vertical, 4)
            HotkeyRecorderRow(action: .pasteLatestPlainText, bindings: bindings)
            HotkeyRecorderRow(action: .togglePopover, bindings: bindings)
            HotkeyRecorderRow(action: .togglePrivacyMode, bindings: bindings)
            HotkeyRecorderRow(action: .captureScreenshotCrop, bindings: bindings)
            HStack {
                Spacer()
                Button("Reset all to defaults") { bindings.resetAll() }
                    .controlSize(.small)
            }
            .padding(.top, 4)
        }
    }
}
