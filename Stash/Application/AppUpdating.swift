import Foundation

/// Update-check capability, kept behind a protocol so Presentation never imports
/// the concrete updater framework. Implemented in Infrastructure.
@MainActor
protocol AppUpdating: AnyObject {
    var automaticallyChecksForUpdates: Bool { get set }
    var canCheckForUpdates: Bool { get }
    var onCanCheckForUpdatesChange: ((Bool) -> Void)? { get set }
    func checkForUpdates()
}
