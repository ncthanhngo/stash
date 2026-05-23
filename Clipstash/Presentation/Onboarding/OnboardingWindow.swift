import AppKit
import SwiftUI

@MainActor
final class OnboardingWindowController {
    static let didOnboardKey = "clipstash.onboarded"

    private var window: NSWindow?

    var hasShownBefore: Bool {
        UserDefaults.standard.bool(forKey: Self.didOnboardKey)
    }

    func showIfNeeded() {
        guard !hasShownBefore else { return }
        show()
    }

    func show() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let view = OnboardingView { [weak self] in
            UserDefaults.standard.set(true, forKey: Self.didOnboardKey)
            self?.window?.close()
        }
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Welcome to Clipstash"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 560, height: 620))
        window.center()
        window.isReleasedWhenClosed = false
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct OnboardingView: View {
    let onDone: () -> Void
    @State private var accessibilityTrusted: Bool = AccessibilityPermission.isTrusted()
    @State private var checkTimer: Timer?

    var body: some View {
        VStack(spacing: 20) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    featureRow(
                        symbol: "doc.text",
                        title: "Copy anything",
                        subtitle: "Text and images are saved to history automatically (500 items / 100 MB FIFO)."
                    )
                    featureRow(
                        symbol: "square.grid.3x3.fill",
                        title: "9 pinned slots",
                        subtitle: "Click an empty slot chip to save text, or right-click a history row → Pin to slot."
                    )
                    featureRow(
                        symbol: "command",
                        title: "Hotkeys",
                        subtitle: "⌥1..9 paste a slot · ⇧⌘V paste most recent (plain) · ⇧⌘C toggle popover."
                    )
                    featureRow(
                        symbol: "curlybraces",
                        title: "Templates",
                        subtitle: "Slots can hold {{date}}, {{clipboard}}, {{uuid}}, $|$ cursor marker."
                    )
                    featureRow(
                        symbol: "icloud.and.arrow.up",
                        title: "Optional sync",
                        subtitle: "Settings → Sync → pick any folder synced by OneDrive / iCloud Drive / Dropbox."
                    )
                }
                .padding(.vertical, 4)
            }
            Divider()
            accessibilitySection
            Spacer(minLength: 0)
            HStack {
                Spacer()
                Button(action: onDone) {
                    Text("Get started").frame(minWidth: 110)
                }
                .controlSize(.large)
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(28)
        .frame(width: 560, height: 620)
        .onAppear { startTrustPolling() }
        .onDisappear { checkTimer?.invalidate() }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 44))
                .foregroundColor(.accentColor)
            Text("Welcome to Clipstash").font(.title.weight(.bold))
            Text("Local-first clipboard manager for macOS")
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func featureRow(symbol: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 18))
                .foregroundColor(.accentColor)
                .frame(width: 26, alignment: .center)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.body.weight(.semibold))
                Text(subtitle).font(.callout).foregroundColor(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private var accessibilitySection: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: accessibilityTrusted
                  ? "checkmark.seal.fill"
                  : "exclamationmark.triangle.fill")
                .font(.system(size: 22))
                .foregroundColor(accessibilityTrusted ? .green : .orange)
            VStack(alignment: .leading, spacing: 4) {
                Text("Accessibility permission").font(.body.weight(.semibold))
                Text(accessibilityTrusted
                     ? "Granted — auto-paste works. You're ready to go."
                     : "Required so Clipstash can simulate Cmd+V into other apps. Without it, ⌥N still copies to the clipboard but you'll need to press Cmd+V manually.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if !accessibilityTrusted {
                Button("Open Settings") { AccessibilityPrompt.openSettings() }
                    .controlSize(.large)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(accessibilityTrusted
                      ? Color.green.opacity(0.08)
                      : Color.orange.opacity(0.1))
        )
    }

    private func startTrustPolling() {
        checkTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                accessibilityTrusted = AccessibilityPermission.isTrusted()
            }
        }
    }
}
