import Foundation

/// Decides whether to show the onboarding window on launch, and in which mode.
/// Replaces the previous "always-prompt-then-onboard" sequence so the user sees
/// Stash's explanation *before* macOS's bare Accessibility prompt.
@MainActor
enum OnboardingCoordinator {
    enum Mode {
        /// Fresh install — show full tour with permission CTA on the last page.
        case firstRun
        /// Repeat launch with permission revoked since last run — show tour with
        /// a top banner explaining the permission was lost.
        case permissionLost
        /// User invoked "Show welcome window again" from Settings.
        case replay
    }

    /// Returns the mode to launch onboarding with, or `nil` if onboarding should
    /// be skipped this launch (permission already granted on a repeat launch).
    static func decide(
        accessibilityTrusted: Bool,
        hasShownBefore: Bool
    ) -> Mode? {
        if accessibilityTrusted { return nil }
        return hasShownBefore ? .permissionLost : .firstRun
    }
}
