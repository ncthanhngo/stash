import Foundation
import Sparkle

/// Sparkle-backed `AppUpdating`. Owns the standard updater controller (which also
/// supplies Sparkle's update UI). The only network the app performs: fetching the
/// appcast feed and downloading a release the user accepts. No history ever leaves
/// the Mac. See CLAUDE.md §7 rule 1 (Phase 11 updater exception).
@MainActor
final class SparkleUpdater: NSObject, AppUpdating {
    private let controller: SPUStandardUpdaterController
    private var canCheckObservation: NSKeyValueObservation?

    var onCanCheckForUpdatesChange: ((Bool) -> Void)?

    override init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
        canCheckObservation = controller.updater.observe(
            \.canCheckForUpdates,
            options: [.initial, .new]
        ) { [weak self] updater, _ in
            let value = updater.canCheckForUpdates
            Task { @MainActor in self?.onCanCheckForUpdatesChange?(value) }
        }
    }

    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    var canCheckForUpdates: Bool { controller.updater.canCheckForUpdates }

    func checkForUpdates() { controller.checkForUpdates(nil) }
}
