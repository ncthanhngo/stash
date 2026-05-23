import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var exclusions: ExclusionList
    @ObservedObject var sync: PinnedFolderSync
    @AppStorage("clipstash.maxItems") private var maxItems: Int = 500
    @AppStorage("clipstash.maxMB") private var maxMB: Int = 100
    @AppStorage("clipstash.restorePrevious") private var restorePrevious: Bool = true

    var body: some View {
        TabView {
            storageTab.tabItem { Label("Storage", systemImage: "internaldrive") }
            generalTab.tabItem { Label("General", systemImage: "gear") }
            exclusionsTab.tabItem { Label("Exclusions", systemImage: "hand.raised") }
            syncTab.tabItem { Label("Sync", systemImage: "arrow.triangle.2.circlepath") }
        }
        .frame(width: 480, height: 420)
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

    private var exclusionsTab: some View {
        Form {
            Section("Built-in (always blocked)") {
                ForEach(exclusions.sortedDefaultBundleIDs, id: \.self) { id in
                    Text(id).font(.system(.callout, design: .monospaced))
                }
            }
            Section("Your additions") {
                if exclusions.sortedUserBundleIDs.isEmpty {
                    Text("None. Use the button below to add apps you never want captured.")
                        .font(.caption).foregroundColor(.secondary)
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

    private var syncTab: some View {
        Form {
            Section("Pinned-slot sync") {
                if let path = sync.folderPath {
                    LabeledContent("Folder", value: path)
                        .font(.system(.callout, design: .monospaced))
                    Button("Disable sync", role: .destructive) { sync.disable() }
                } else {
                    Text("Pick a folder synced by OneDrive, iCloud Drive, Dropbox, or Google Drive. Clipstash writes per-slot files into a `Clipstash/` subfolder. History stays on this Mac.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("Pick folder…") { pickSyncFolder() }
                }
            }
            Section {
                Text("Last-write-wins per slot. Items larger than 5 MB or from excluded apps are skipped.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func pickSyncFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder synced by your cloud client"
        if panel.runModal() == .OK, let url = panel.url {
            sync.enable(folderURL: url)
        }
    }
}
