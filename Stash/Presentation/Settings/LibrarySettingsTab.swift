import SwiftUI
import AppKit
import ServiceManagement

struct LibrarySettingsTab: View {
    @ObservedObject var sync: PinnedFolderSync
    let portability: HistoryPortabilityService
    let topPastedProvider: () -> [ClipboardItem]
    @State private var topPasted: [ClipboardItem] = []
    @State private var portabilityError: String?
    @AppStorage("stash.restorePrevious") private var restorePrevious: Bool = true
    @AppStorage("stash.stickyPopover") private var stickyPopover: Bool = false
    @AppStorage(VaultStore.unlockEnabledKey) private var vaultUnlockEnabled: Bool = false
    @AppStorage(VaultStore.unlockSecondsKey) private var vaultUnlockSeconds: Int = 30
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
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
                Text("Last-write-wins per slot. Items larger than 5 MB or from excluded apps are skipped.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("History portability") {
                HStack {
                    Button("Export history…") { exportBundle() }
                    Button("Import history…") { importBundle() }
                    Spacer()
                }
                Text("Saves your entire history (text + images + pinned slots) as a single `.stashbundle` file. Import replaces the current history — back up first if you want both.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let portabilityError {
                    Text(portabilityError)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            Section("Vault") {
                Button("Open Vault") {
                    NotificationCenter.default.post(name: .stashOpenVault, object: nil)
                }
                Text("Touch-ID-protected slots for secrets.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Toggle("Skip Touch ID for a short window after authentication", isOn: $vaultUnlockEnabled)
                Stepper(
                    "Unlock window: \(vaultUnlockSeconds)s",
                    value: $vaultUnlockSeconds,
                    in: 10...300,
                    step: 10
                )
                .disabled(!vaultUnlockEnabled)
                Text("While unlocked, vault items paste without Touch ID — useful for snippet authoring. Locks automatically when Stash loses focus or the screen sleeps.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Tools") {
                Button("Open Snippets") {
                    NotificationCenter.default.post(name: .stashOpenSnippets, object: nil)
                }
                Text("Folders + reusable snippets with optional template variables.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button("Reveal browser extension folder…") { revealExtensionFolder() }
                Text("Right-click selected text in Chrome/Brave/Edge → Send to Stash slot.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Insights — top pasted") {
                if topPasted.isEmpty {
                    Text("No paste counts yet — paste something via your slot hotkeys to populate.")
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

            Section("Help") {
                Button("Show welcome window again") {
                    OnboardingWindowController().show()
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

    private func exportBundle() {
        portabilityError = nil
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Stash-\(Self.timestamp()).stashbundle"
        panel.message = "Save your full Stash history as a single file"
        panel.allowedContentTypes = []
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try portability.exportBundle(to: url)
        } catch {
            portabilityError = "Export failed: \(String(describing: error))"
        }
    }

    private func importBundle() {
        portabilityError = nil
        let alert = NSAlert()
        alert.messageText = "Replace history with imported bundle?"
        alert.informativeText = "Your current history will be discarded. Export it first if you want to keep both."
        alert.addButton(withTitle: "Choose Bundle…")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Pick a .stashbundle file"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try portability.importBundle(from: url)
        } catch {
            portabilityError = "Import failed: \(String(describing: error))"
        }
    }

    private static func timestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmm"
        return f.string(from: Date())
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
}
