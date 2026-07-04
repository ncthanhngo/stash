import SwiftUI
import AppKit

/// Hand-rolled 4-page pager. macOS 13 lacks SwiftUI's `.page` style on TabView,
/// so we drive pages with a state index + Next/Back buttons + tappable dots.
struct OnboardingPagerView: View {
    let mode: OnboardingCoordinator.Mode
    let onDone: () -> Void

    @State private var page: Int = 0
    @State private var accessibilityTrusted: Bool = AccessibilityPermission.isTrusted()
    @State private var pollTimer: Timer?

    private let pageCount = 4

    var body: some View {
        VStack(spacing: 0) {
            if mode == .permissionLost {
                permissionLostBanner
            }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 32)
            Divider()
            footer
                .padding(20)
        }
        .frame(width: 600, height: mode == .permissionLost ? 560 : 520)
        .onAppear { startPolling() }
        .onDisappear { pollTimer?.invalidate() }
    }

    // MARK: - Pages

    @ViewBuilder
    private var content: some View {
        switch page {
        case 0: WelcomePage()
        case 1: PinnedSlotsPage()
        case 2: HiddenPowersPage()
        default: PermissionPage(trusted: accessibilityTrusted)
        }
    }

    // MARK: - Chrome

    private var permissionLostBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text("Stash lost Accessibility access. Auto-paste is off until you grant it again.")
                .font(.callout)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.orange.opacity(0.12))
    }

    private var footer: some View {
        HStack {
            Button("Skip", action: dismiss)
                .controlSize(.large)
            Spacer()
            HStack(spacing: 6) {
                ForEach(0..<pageCount, id: \.self) { i in
                    Circle()
                        .fill(i == page ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 6, height: 6)
                        .onTapGesture { page = i }
                }
            }
            Spacer()
            if page < pageCount - 1 {
                Button("Next") { page += 1 }
                    .controlSize(.large)
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
            } else {
                Button(accessibilityTrusted ? "Get started" : "Grant Accessibility") {
                    if accessibilityTrusted {
                        dismiss()
                    } else {
                        AccessibilityPermission.requestIfNeeded()
                        AccessibilityPrompt.openSettings()
                    }
                }
                .controlSize(.large)
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func dismiss() {
        pollTimer?.invalidate()
        onDone()
    }

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                let trusted = AccessibilityPermission.isTrusted()
                if trusted != accessibilityTrusted {
                    accessibilityTrusted = trusted
                }
            }
        }
    }
}

// MARK: - Individual pages

private struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 64, weight: .light))
                .foregroundColor(.accentColor)
            Text("Welcome to Stash")
                .font(.largeTitle.bold())
            Text("Your clipboard, captured. Searched. Pinned. Pasted with one keystroke.")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Text("Everything lives on this Mac — no backend, no telemetry, no login.")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }
}

private struct PinnedSlotsPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer(minLength: 8)
            HStack(spacing: 12) {
                Image(systemName: "square.grid.3x3.fill")
                    .font(.system(size: 42))
                    .foregroundColor(.accentColor)
                Text("9 pinned slots")
                    .font(.title.bold())
            }
            Text("Pin frequent text to slots **1–9** and paste with one chord.")
                .font(.title3)
            VStack(alignment: .leading, spacing: 10) {
                bullet("⌥1 … ⌥9", "Paste the matching slot into the focused app.")
                bullet("⇧⌘V", "Paste the most recent clipboard item (plain text).")
                bullet("⇧⌘C", "Show or hide the Stash popover.")
                bullet("Settings → Capture → Hotkeys", "Rebind anything that collides with another app.")
            }
            Spacer()
        }
    }

    private func bullet(_ key: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(key)
                .font(.system(.callout, design: .monospaced).weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.accentColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 5))
            Text(text)
                .font(.callout)
            Spacer(minLength: 0)
        }
    }
}

private struct HiddenPowersPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer(minLength: 8)
            HStack(spacing: 12) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 42))
                    .foregroundColor(.accentColor)
                Text("Hidden powers")
                    .font(.title.bold())
            }
            Text("Five features most clipboard managers don't have.")
                .font(.title3)
            VStack(alignment: .leading, spacing: 10) {
                row("lock.shield", "Touch-ID Vault", "Touch ID-protected slots for secrets.")
                row("text.book.closed", "Snippets + variables", "Reusable text with {{date}}, {{uuid}}, prompts.")
                row("text.viewfinder", "OCR on images", "Right-click an image item to extract its text.")
                row("rectangle.dashed", "Screen crop", "⇧⌘S crops a region straight into history.")
                row("globe", "Browser extension", "Right-click selected text → Send to Stash slot.")
            }
            Spacer()
        }
    }

    private func row(_ symbol: String, _ title: String, _ subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 26, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.semibold))
                Text(subtitle).font(.callout).foregroundColor(.secondary)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct PermissionPage: View {
    let trusted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer(minLength: 8)
            HStack(spacing: 12) {
                Image(systemName: trusted ? "checkmark.seal.fill" : "key.horizontal.fill")
                    .font(.system(size: 42))
                    .foregroundColor(trusted ? .green : .accentColor)
                Text(trusted ? "You're all set" : "One permission")
                    .font(.title.bold())
            }
            if trusted {
                Text("Accessibility access granted. Stash can simulate ⌘V for you on every paste hotkey.")
                    .font(.callout)
            } else {
                Text("Stash needs **Accessibility** access to simulate ⌘V into other apps. Without it, your hotkeys still copy the slot to the clipboard — you'll just need to press ⌘V yourself.")
                    .font(.callout)
                explanationCard
            }
            Spacer()
        }
    }

    private var explanationCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("What Stash does with this access", systemImage: "lock.shield")
                .font(.callout.weight(.semibold))
            Text("• Simulate ⌘V when you trigger a paste hotkey.")
            Text("• Read the bundle ID of the frontmost app, so privacy exclusions work.")
            Label("What Stash never does", systemImage: "xmark.shield")
                .font(.callout.weight(.semibold))
                .padding(.top, 6)
            Text("• Capture keystrokes outside of Stash hotkeys.")
            Text("• Read your screen, your microphone, or any data on the network.")
        }
        .font(.callout)
        .foregroundColor(.secondary)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.accentColor.opacity(0.08))
        )
    }
}
