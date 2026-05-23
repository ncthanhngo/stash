import SwiftUI
import AppKit
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var exclusions: ExclusionList
    @ObservedObject var sync: PinnedFolderSync
    @ObservedObject var privacyMode: PrivacyModeState
    let topPastedProvider: () -> [ClipboardItem]
    @State private var topPasted: [ClipboardItem] = []
    @AppStorage("stash.maxItems") private var maxItems: Int = 500
    @AppStorage("stash.maxMB") private var maxMB: Int = 100
    @AppStorage("stash.autoDeleteAfterDays") private var autoDeleteAfterDays: Int = 0
    @AppStorage("stash.restorePrevious") private var restorePrevious: Bool = true
    @AppStorage("stash.stickyPopover") private var stickyPopover: Bool = false
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    @State private var accessibilityTrusted: Bool = AccessibilityPermission.isTrusted()

    var body: some View {
        TabView {
            storageTab.tabItem { Label("Storage", systemImage: "internaldrive") }
            generalTab.tabItem { Label("General", systemImage: "gear") }
            exclusionsTab.tabItem { Label("Exclusions", systemImage: "hand.raised") }
            syncTab.tabItem { Label("Sync", systemImage: "arrow.triangle.2.circlepath") }
            insightsTab.tabItem { Label("Insights", systemImage: "chart.bar") }
            vaultTab.tabItem { Label("Vault", systemImage: "lock.shield") }
        }
        .frame(width: 480, height: 420)
        .padding()
    }

    private var vaultTab: some View {
        Form {
            Section("Touch ID secure slots") {
                Text("Open the Vault window to add, view, and paste secrets. Each paste requires Touch ID.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button("Open Vault") { openVault() }
            }
            Section("Snippet library") {
                Text("Folders + reusable snippets with optional template variables. Paste from the Snippets window.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button("Open Snippets") { openSnippets() }
            }
            Section("Browser extension") {
                Text("Right-click selected text in Chrome/Brave/Edge → Send to Stash slot. Load the unpacked extension from the browser-extension/ folder in this repo.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button("Reveal extension folder in Finder") { revealExtensionFolder() }
            }
        }
        .formStyle(.grouped)
    }

    private func openVault() {
        NotificationCenter.default.post(name: .stashOpenVault, object: nil)
    }

    private func openSnippets() {
        NotificationCenter.default.post(name: .stashOpenSnippets, object: nil)
    }

    private func revealExtensionFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Locate the Stash repo's browser-extension folder"
        panel.prompt = "Reveal"
        if panel.runModal() == .OK, let url = panel.url {
            let ext = url.appendingPathComponent("browser-extension")
            let target = FileManager.default.fileExists(atPath: ext.path) ? ext : url
            NSWorkspace.shared.activateFileViewerSelecting([target])
        }
    }

    private var storageTab: some View {
        Form {
            Section("Limits (applies on next launch)") {
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
            }
            Section {
                Text("FIFO eviction fires whichever hits first (count, size, or age). Pinned slots are never evicted.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var generalTab: some View {
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
                         : "Accessibility needed for ⌥1..9 auto-paste")
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
            Section("Launch") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        toggleLaunchAtLogin(newValue)
                    }
            }
            Section("Paste behaviour") {
                Toggle("Restore previous clipboard after paste", isOn: $restorePrevious)
                Toggle("Keep popover open after paste (sticky)", isOn: $stickyPopover)
            }
            Section("Hotkeys") {
                LabeledContent("Paste slot 1–9", value: "⌥1 … ⌥9")
                LabeledContent("Paste most-recent (plain)", value: "⇧⌘V")
                LabeledContent("Toggle popover", value: "⇧⌘C  /  ⇧⌥⌘V")
            }
            Section("Help") {
                Button("Show welcome window again") { showOnboarding() }
            }
        }
        .formStyle(.grouped)
    }

    private func showOnboarding() {
        OnboardingWindowController().show()
    }

    private var insightsTab: some View {
        Form {
            Section("Top pasted items") {
                if topPasted.isEmpty {
                    Text("No paste counts yet — paste something via ⌥1..9 or click to populate.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                ForEach(topPasted) { item in
                    HStack(spacing: 8) {
                        Text("\(item.pasteCount)\u{00D7}")
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundColor(.accentColor)
                            .frame(width: 36, alignment: .trailing)
                        Text(item.textPreview ?? "—")
                            .font(.callout)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer()
                        if let slot = item.pinnedSlot {
                            Text("⌥\(slot)")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 4)
                                .background(Color.accentColor.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { topPasted = topPastedProvider() }
    }

    private func toggleLaunchAtLogin(_ enable: Bool) {
        do {
            if enable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = !enable
        }
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
                    Text("Pick a folder synced by OneDrive, iCloud Drive, Dropbox, or Google Drive. Stash writes per-slot files into a `Stash/` subfolder. History stays on this Mac.")
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
