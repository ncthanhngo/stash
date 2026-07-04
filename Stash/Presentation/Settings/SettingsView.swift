import SwiftUI

/// 4-tab Settings router. Each tab lives in its own file.
struct SettingsView: View {
    @ObservedObject var exclusions: ExclusionList
    @ObservedObject var sync: PinnedFolderSync
    @ObservedObject var privacyMode: PrivacyModeState
    @ObservedObject var hotkeyBindings: HotkeyBindings
    @ObservedObject var updater: UpdaterViewModel
    let portability: HistoryPortabilityService
    let topPastedProvider: () -> [ClipboardItem]

    var body: some View {
        TabView {
            CaptureSettingsTab(
                privacyMode: privacyMode,
                exclusions: exclusions,
                hotkeyBindings: hotkeyBindings
            )
            .tabItem { Label("Capture", systemImage: "square.and.arrow.down") }

            LibrarySettingsTab(
                sync: sync,
                portability: portability,
                topPastedProvider: topPastedProvider
            )
            .tabItem { Label("Library", systemImage: "books.vertical") }

            UpdatesSettingsView(updater: updater)
                .tabItem { Label("Updates", systemImage: "arrow.down.circle") }

            AboutSettingsTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 600, height: 500)
        .padding()
    }
}
