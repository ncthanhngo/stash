import SwiftUI

struct SettingsView: View {
    @AppStorage("clipstash.maxItems") private var maxItems: Int = 500
    @AppStorage("clipstash.maxMB") private var maxMB: Int = 100
    @AppStorage("clipstash.restorePrevious") private var restorePrevious: Bool = true

    var body: some View {
        TabView {
            storageTab.tabItem { Label("Storage", systemImage: "internaldrive") }
            generalTab.tabItem { Label("General", systemImage: "gear") }
        }
        .frame(width: 460, height: 360)
        .padding()
    }

    private var storageTab: some View {
        Form {
            Section("Limits (applies on next launch)") {
                Stepper("Max items: \(maxItems)", value: $maxItems, in: 50...2000, step: 50)
                Stepper("Max size: \(maxMB) MB", value: $maxMB, in: 10...1024, step: 10)
            }
            Section {
                Text("Whichever limit is hit first triggers FIFO eviction of non-pinned items. Pinned slots are never evicted.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var generalTab: some View {
        Form {
            Section("Paste behaviour") {
                Toggle("Restore previous clipboard after paste", isOn: $restorePrevious)
            }
            Section("Hotkeys") {
                LabeledContent("Paste slot 1–9", value: "⌥1 … ⌥9")
                LabeledContent("Plain-text paste", value: "⇧⌘V")
                LabeledContent("Toggle popover", value: "⇧⌘C")
            }
        }
        .formStyle(.grouped)
    }
}
