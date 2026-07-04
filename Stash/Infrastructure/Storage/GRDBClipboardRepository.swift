import Foundation
import GRDB
import Combine
import os

final class GRDBClipboardRepository: ClipboardRepository {
    private static let log = Logger(subsystem: "com.soi.stash", category: "storage")

    private let writer: any DatabaseWriter
    private let settingsProvider: @Sendable () -> StorageSettings
    private let dbURL: URL?
    private let pinChangesSubject = PassthroughSubject<Void, Never>()

    var pinChanges: AnyPublisher<Void, Never> { pinChangesSubject.eraseToAnyPublisher() }

    private var settings: StorageSettings { settingsProvider() }

    init(
        writer: any DatabaseWriter,
        settingsProvider: @escaping @Sendable () -> StorageSettings = { .defaults },
        dbURL: URL? = nil
    ) {
        self.writer = writer
        self.settingsProvider = settingsProvider
        self.dbURL = dbURL
    }

    convenience init(writer: any DatabaseWriter, settings: StorageSettings = .defaults) {
        self.init(writer: writer, settingsProvider: { settings })
    }

    convenience init(
        dbPool: DatabasePool,
        settingsProvider: @escaping @Sendable () -> StorageSettings,
        dbURL: URL? = nil
    ) {
        self.init(writer: dbPool, settingsProvider: settingsProvider, dbURL: dbURL)
    }

    convenience init(dbPool: DatabasePool, settings: StorageSettings = .defaults) {
        self.init(writer: dbPool, settingsProvider: { settings })
    }

    func insert(_ item: ClipboardItem) throws {
        var affectedPinned = false
        var enrichedItem = item
        if enrichedItem.expiresAt == nil, !item.isPinned, case .text(let s) = item.content,
           let kind = SensitivePatternDetector.detect(in: s)
        {
            enrichedItem.expiresAt = item.createdAt.addingTimeInterval(kind.defaultTTL)
        }
        try writer.write { db in
            if let existing = try ClipboardRecord
                .filter(Column("content_hash") == enrichedItem.contentHash)
                .filter(Column("is_pinned") == false)
                .fetchOne(db)
            {
                try existing.delete(db)
            }
            try ClipboardRecord(from: enrichedItem).insert(db)
            if enrichedItem.isPinned { affectedPinned = true }
            try self.evictIfNeeded(in: db)
        }
        if affectedPinned { pinChangesSubject.send() }
    }

    func recordPaste(itemID: UUID) throws {
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        try writer.write { db in
            try db.execute(
                sql: "UPDATE clipboard_items SET paste_count = paste_count + 1, last_pasted_at = ? WHERE id = ?",
                arguments: [nowMs, itemID.uuidString]
            )
        }
    }

    func topPasted(limit: Int = 10) throws -> [ClipboardItem] {
        try writer.read { db in
            try ClipboardRecord
                .filter(Column("paste_count") > 0)
                .order(Column("paste_count").desc, Column("last_pasted_at").desc)
                .limit(limit)
                .fetchAll(db)
                .compactMap { $0.toItem() }
        }
    }

    func deleteExpired() throws -> Int {
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        return try writer.write { db in
            let count = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM clipboard_items WHERE expires_at IS NOT NULL AND expires_at < ? AND is_pinned = 0",
                arguments: [nowMs]
            ) ?? 0
            try db.execute(
                sql: "DELETE FROM clipboard_items WHERE expires_at IS NOT NULL AND expires_at < ? AND is_pinned = 0",
                arguments: [nowMs]
            )
            return count
        }
    }

    func recent(limit: Int = 200) throws -> [ClipboardItem] {
        try writer.read { db in
            try ClipboardRecord
                .order(Column("created_at").desc)
                .limit(limit)
                .fetchAll(db)
                .compactMap { $0.toItem() }
        }
    }

    func pinned() throws -> [ClipboardItem] {
        try writer.read { db in
            try ClipboardRecord
                .filter(Column("is_pinned") == true)
                .order(Column("pinned_slot").asc)
                .fetchAll(db)
                .compactMap { $0.toItem() }
        }
    }

    func pin(itemID: UUID, slot: Int) throws {
        guard (1...9).contains(slot) else { throw StorageError.invalidSlot(slot) }
        try writer.write { db in
            try db.execute(
                sql: "UPDATE clipboard_items SET is_pinned = 0, pinned_slot = NULL, pinned_template = NULL WHERE pinned_slot = ?",
                arguments: [slot]
            )
            try db.execute(
                sql: "UPDATE clipboard_items SET is_pinned = 1, pinned_slot = ? WHERE id = ?",
                arguments: [slot, itemID.uuidString]
            )
        }
        pinChangesSubject.send()
    }

    func unpin(slot: Int) throws {
        try writer.write { db in
            try db.execute(
                sql: "UPDATE clipboard_items SET is_pinned = 0, pinned_slot = NULL, pinned_template = NULL WHERE pinned_slot = ?",
                arguments: [slot]
            )
        }
        pinChangesSubject.send()
    }

    func delete(itemID: UUID) throws {
        var deletedPinned = false
        try writer.write { db in
            if let record = try ClipboardRecord
                .filter(Column("id") == itemID.uuidString)
                .fetchOne(db)
            {
                if record.isPinned { deletedPinned = true }
                try record.delete(db)
            }
        }
        if deletedPinned { pinChangesSubject.send() }
    }

    func clearHistory() throws {
        // Pinned slots carry is_pinned = 1, so they survive this wipe.
        try writer.write { db in
            try db.execute(sql: "DELETE FROM clipboard_items WHERE is_pinned = 0")
        }
    }

    func search(query: String, limit: Int = 200) throws -> [ClipboardItem] {
        guard !query.isEmpty else { return try recent(limit: limit) }
        let like = "%\(query)%"
        return try writer.read { db in
            try ClipboardRecord
                .filter(
                    sql: "text_preview LIKE ? COLLATE NOCASE OR source_app_name LIKE ? COLLATE NOCASE",
                    arguments: [like, like]
                )
                .order(Column("created_at").desc)
                .limit(limit * 2)
                .fetchAll(db)
                .compactMap { $0.toItem() }
        }
    }

    func findByHash(_ hash: String) throws -> ClipboardItem? {
        try writer.read { db in
            try ClipboardRecord
                .filter(Column("content_hash") == hash)
                .fetchOne(db)?
                .toItem()
        }
    }

    func setPinnedTemplate(slot: Int, template: String?) throws {
        try writer.write { db in
            try db.execute(
                sql: "UPDATE clipboard_items SET pinned_template = ? WHERE pinned_slot = ?",
                arguments: [template, slot]
            )
        }
        pinChangesSubject.send()
    }

    func applyLimitsNow() throws {
        try writer.write { db in
            try self.evictIfNeeded(in: db)
        }
    }

    func backupSQLite() throws -> Data {
        // Force a checkpoint so the on-disk file is consistent, then read it.
        try writer.write { db in
            try db.checkpoint()
        }
        guard let url = dbURL else {
            throw NSError(
                domain: "GRDBClipboardRepository",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Backup unavailable: in-memory database"]
            )
        }
        return try Data(contentsOf: url)
    }

    func restoreSQLite(from data: Data) throws {
        guard let url = dbURL else {
            throw NSError(
                domain: "GRDBClipboardRepository",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Restore unavailable: in-memory database"]
            )
        }
        // Wipe existing rows in the live connection, then overwrite the file.
        try writer.write { db in
            try db.execute(sql: "DELETE FROM clipboard_items")
        }
        try data.write(to: url, options: .atomic)
        // GRDB caches the schema; force a re-open by VACUUMing.
        try writer.write { db in
            try db.execute(sql: "VACUUM")
        }
    }

    private func evictIfNeeded(in db: Database) throws {
        if settings.autoDeleteAfterDays > 0 {
            let cutoff = Int64(
                (Date().timeIntervalSince1970 - Double(settings.autoDeleteAfterDays) * 86_400) * 1000
            )
            try db.execute(
                sql: "DELETE FROM clipboard_items WHERE is_pinned = 0 AND created_at < ?",
                arguments: [cutoff]
            )
        }

        var count = try Int.fetchOne(
            db, sql: "SELECT COUNT(*) FROM clipboard_items WHERE is_pinned = 0"
        ) ?? 0
        var totalSize = try Int.fetchOne(
            db, sql: "SELECT COALESCE(SUM(size_bytes), 0) FROM clipboard_items WHERE is_pinned = 0"
        ) ?? 0

        while count > settings.maxItems || totalSize > settings.maxBytes {
            guard let oldest = try ClipboardRecord
                .filter(Column("is_pinned") == false)
                .order(Column("created_at").asc)
                .limit(1)
                .fetchOne(db)
            else { break }
            try oldest.delete(db)
            count -= 1
            totalSize -= oldest.sizeBytes
        }
    }
}
