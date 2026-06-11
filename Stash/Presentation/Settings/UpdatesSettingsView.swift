import SwiftUI

struct UpdatesSettingsView: View {
    @ObservedObject var updater: UpdaterViewModel

    var body: some View {
        Form {
            Section("Software update") {
                Toggle("Automatically check for updates", isOn: $updater.automaticallyChecksForUpdates)
                Button("Check for Updates…") { updater.checkForUpdates() }
                    .disabled(!updater.canCheckForUpdates)
            }
            Section {
                Text("Stash contacts GitHub only to look for a newer release and, if you accept, to download it. History and clipboard contents never leave this Mac.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
