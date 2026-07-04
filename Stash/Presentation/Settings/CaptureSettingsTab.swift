import SwiftUI
import AppKit

struct CaptureSettingsTab: View {
    @ObservedObject var privacyMode: PrivacyModeState
    @ObservedObject var exclusions: ExclusionList
    @ObservedObject var hotkeyBindings: HotkeyBindings
    @AppStorage("stash.maxItems") private var maxItems: Int = 500
    @AppStorage("stash.maxMB") private var maxMB: Int = 100
    @AppStorage("stash.autoDeleteAfterDays") private var autoDeleteAfterDays: Int = 0
    @State private var accessibilityTrusted: Bool = AccessibilityPermission.isTrusted()

    var body: some View {
        Form {
            Section("Privacy") {
                Toggle("Pause clipboard capture", isOn: $privacyMode.isPaused)
                Text("Hotkey: ⇧⌥⌘P — toggle anytime. Status icon changes when paused.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Permissions") {
                HStack {
                    Image(systemName: accessibilityTrusted
                          ? "checkmark.circle.fill"
                          : "exclamationmark.triangle.fill")
                        .foregroundColor(accessibilityTrusted ? .green : .orange)
                    Text(accessibilityTrusted
                         ? "Accessibility granted — auto-paste works"
                         : "Accessibility needed for paste-slot hotkeys")
                    Spacer()
                    if !accessibilityTrusted {
                        Button("Open Settings") { AccessibilityPrompt.openSettings() }
                    }
                    Button {
                        accessibilityTrusted = AccessibilityPermission.isTrusted()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("Re-check")
                }
            }

            Section("Capture limits") {
                Stepper("Max items: \(maxItems)", value: $maxItems, in: 50...2000, step: 50)
                Stepper("Max size: \(maxMB) MB", value: $maxMB, in: 10...1024, step: 10)
                Stepper(
                    autoDeleteAfterDays == 0
                        ? "Auto-delete: never"
                        : "Auto-delete after \(autoDeleteAfterDays) day\(autoDeleteAfterDays == 1 ? "" : "s")",
                    value: $autoDeleteAfterDays,
                    in: 0...365,
                    step: 1
                )
                Text("FIFO eviction fires whichever hits first (count, size, or age). Pinned slots are never evicted.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Hotkeys") {
                HotkeyBindingTable(bindings: hotkeyBindings)
                Text("Click Record on any row to rebind. Esc cancels. Use the menu (•••) to disable an action or restore the default.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Exclusions") {
                DisclosureGroup("Built-in (always blocked)") {
                    ForEach(exclusions.sortedDefaultBundleIDs, id: \.self) { id in
                        Text(id).font(.system(.caption, design: .monospaced))
                    }
                }
                if exclusions.sortedUserBundleIDs.isEmpty {
                    Text("No user exclusions. Add apps you never want Stash to capture from.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                ForEach(exclusions.sortedUserBundleIDs, id: \.self) { id in
                    HStack {
                        Text(id).font(.system(.callout, design: .monospaced))
                        Spacer()
                        Button("Remove") { exclusions.remove(id) }
                            .buttonStyle(.borderless)
                    }
                }
                Button("Add app…") { pickApp() }
            }
        }
        .formStyle(.grouped)
    }

    private func pickApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK,
              let url = panel.url,
              let bundle = Bundle(url: url),
              let id = bundle.bundleIdentifier
        else { return }
        exclusions.add(id)
    }
}
