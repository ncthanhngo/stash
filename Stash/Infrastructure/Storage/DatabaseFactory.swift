import Foundation
import GRDB
import os

enum DatabaseFactory {
    private static let log = Logger(subsystem: "com.soi.stash", category: "storage")

    static var defaultURL: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return appSupport
            .appendingPathComponent("Stash", isDirectory: true)
            .appendingPathComponent("stash.sqlite")
    }

    static func makeShared(at url: URL) throws -> DatabasePool {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var config = Configuration()
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA journal_mode = WAL;")
            try db.execute(sql: "PRAGMA foreign_keys = ON;")
        }

        do {
            let pool = try DatabasePool(path: url.path, configuration: config)
            try Migrations.migrator.migrate(pool)
            return pool
        } catch {
            log.error("DB open failed, moving aside: \(String(describing: error), privacy: .public)")
            let stamp = Int(Date().timeIntervalSince1970)
            let backup = url.appendingPathExtension("corrupt-\(stamp)")
            try? FileManager.default.moveItem(at: url, to: backup)
            let pool = try DatabasePool(path: url.path, configuration: config)
            try Migrations.migrator.migrate(pool)
            return pool
        }
    }
}
