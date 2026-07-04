import AppKit
import SwiftUI

@MainActor
final class OnboardingWindowController {
    static let didOnboardKey = "stash.onboarded"

    private var window: NSWindow?

    var hasShownBefore: Bool {
        UserDefaults.standard.bool(forKey: Self.didOnboardKey)
    }

    func show(mode: OnboardingCoordinator.Mode = .replay) {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let view = OnboardingPagerView(mode: mode) { [weak self] in
            UserDefaults.standard.set(true, forKey: Self.didOnboardKey)
            self?.window?.close()
        }
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = mode == .permissionLost ? "Stash · Permission needed" : "Welcome to Stash"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 600, height: 520))
        window.center()
        window.isReleasedWhenClosed = false
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
