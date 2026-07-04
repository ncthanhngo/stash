import Foundation
import os

/// Builds and consumes single-file `.stashbundle` archives via Foundation's
/// `NSFileWrapper` serialization — no third-party dep required. Schema is a
/// directory file-wrapper with `manifest.json` + `history.sqlite`.
enum HistoryBundleService {
    private static let log = Logger(subsystem: "com.soi.stash", category: "bundle")

    enum BundleError: Error, Equatable {
        case unreadable
        case missingManifest
        case missingDatabase
        case unsupportedSchema(Int)
    }

    /// Write a `.stashbundle` archive of the current history at `destinationURL`.
    static func export(
        sqliteData: Data,
        manifest: HistoryBundleManifest,
        to destinationURL: URL
    ) throws {
        let manifestData = try JSONEncoder.pretty.encode(manifest)
        let root = FileWrapper(directoryWithFileWrappers: [
            "manifest.json": FileWrapper(regularFileWithContents: manifestData),
            "history.sqlite": FileWrapper(regularFileWithContents: sqliteData),
        ])
        guard let archive = root.serializedRepresentation else {
            throw BundleError.unreadable
        }
        try archive.write(to: destinationURL, options: .atomic)
        log.info("exported bundle items=\(sqliteData.count, privacy: .public) to \(destinationURL.lastPathComponent, privacy: .public)")
    }

    /// Read a `.stashbundle` archive at `url` and return its components.
    static func read(from url: URL) throws -> (manifest: HistoryBundleManifest, sqlite: Data) {
        let raw = try Data(contentsOf: url)
        guard let root = FileWrapper(serializedRepresentation: raw) else {
            throw BundleError.unreadable
        }
        guard let manifestData = root.fileWrappers?["manifest.json"]?.regularFileContents else {
            throw BundleError.missingManifest
        }
        guard let sqliteData = root.fileWrappers?["history.sqlite"]?.regularFileContents else {
            throw BundleError.missingDatabase
        }
        let manifest = try JSONDecoder().decode(HistoryBundleManifest.self, from: manifestData)
        guard manifest.schemaVersion <= HistoryBundleManifest.currentSchemaVersion else {
            throw BundleError.unsupportedSchema(manifest.schemaVersion)
        }
        return (manifest, sqliteData)
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return enc
    }
}
