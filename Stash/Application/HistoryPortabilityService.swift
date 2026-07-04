import Foundation

/// Thin orchestration around `HistoryBundleService` + the repository so the
/// presentation layer doesn't reach into Infrastructure directly.
@MainActor
final class HistoryPortabilityService {
    private let repository: any ClipboardRepository
    private let store: ClipboardStore
    private let appVersion: String

    init(repository: any ClipboardRepository, store: ClipboardStore) {
        self.repository = repository
        self.store = store
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    func exportBundle(to url: URL) throws {
        let sqlite = try repository.backupSQLite()
        let manifest = HistoryBundleManifest.current(appVersion: appVersion)
        try HistoryBundleService.export(
            sqliteData: sqlite,
            manifest: manifest,
            to: url
        )
    }

    func importBundle(from url: URL) throws {
        let (_, sqlite) = try HistoryBundleService.read(from: url)
        try repository.restoreSQLite(from: sqlite)
        store.refresh()
    }
}
