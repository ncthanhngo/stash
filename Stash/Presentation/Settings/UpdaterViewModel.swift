import Foundation
import Combine

@MainActor
final class UpdaterViewModel: ObservableObject {
    @Published var canCheckForUpdates: Bool
    @Published var automaticallyChecksForUpdates: Bool {
        didSet { updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates }
    }

    private let updater: AppUpdating

    init(updater: AppUpdating) {
        self.updater = updater
        canCheckForUpdates = updater.canCheckForUpdates
        automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
        updater.onCanCheckForUpdatesChange = { [weak self] value in
            self?.canCheckForUpdates = value
        }
    }

    func checkForUpdates() { updater.checkForUpdates() }
}
