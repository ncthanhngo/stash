import Foundation

/// Metadata about a `.stashbundle` export. Versioned so future readers can
/// reject or migrate incompatible bundles.
struct HistoryBundleManifest: Codable, Equatable {
    /// Bumped any time the bundle layout changes incompatibly.
    let schemaVersion: Int

    /// ISO-8601 timestamp the bundle was produced.
    let exportedAt: String

    /// Marketing version of the producing app (`CFBundleShortVersionString`).
    let appVersion: String

    static let currentSchemaVersion = 1

    static func current(appVersion: String) -> HistoryBundleManifest {
        HistoryBundleManifest(
            schemaVersion: currentSchemaVersion,
            exportedAt: ISO8601DateFormatter().string(from: Date()),
            appVersion: appVersion
        )
    }
}
