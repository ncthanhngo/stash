import Foundation
import GRDB
import Combine
import os

final class GRDBClipboardRepository: ClipboardRepository {
    private static let log = Logger(subsystem: "com.soi.clipstash", category: "storage")

    private let dbPool: DatabasePool
    private let settings: StorageSettings
    private let pinChangesSubject = PassthroughSubject<Void, Never>()

    var pinChanges: AnyPublisher<Void, Never> { pinChangesSubject.eraseToAnyPublisher() }

    init(dbPool: DatabasePool, settings: StorageSettings = .defaults) {
        self.dbPool = dbPool
        self.settings = settings
    }

    func insert(_ item: ClipboardItem) throws {
        var affectedPinned = false
        try dbPool.write { db in
            if let existing = try ClipboardRecord
                .filter(Column("content_hash") == item.contentHash)
                .filter(Column("is_pinned") == false)
                .fetchOne(db)
            {
                try existing.delete(db)
            }
            try ClipboardRecord(from: item).insert(db)
            if item.isPinned { affectedPinned = true }
            try self.evictIfNeeded(in: db)
        }
        if affectedPinned { pinChangesSubject.send() }
    }

    func recent(limit: Int = 200) throws -> [ClipboardItem] {
        try dbPool.read { db in
            try ClipboardRecord
                .order(Column("created_at").desc)
                .limit(limit)
                .fetchAll(db)
                .compactMap { $0.toItem() }
        }
    }

    func pinned() throws -> [ClipboardItem] {
        try dbPool.read { db in
            try ClipboardRecord
                .filter(Column("is_pinned") == true)
                .order(Column("pinned_slot").asc)
                .fetchAll(db)
                .compactMap { $0.toItem() }
        }
    }

    func pin(itemID: UUID, slot: Int) throws {
        guard (1...9).contains(slot) else { throw StorageError.invalidSlot(slot) }
        try dbPool.write { db in
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
        try dbPool.write { db in
            try db.execute(
                sql: "UPDATE clipboard_items SET is_pinned = 0, pinned_slot = NULL, pinned_template = NULL WHERE pinned_slot = ?",
                arguments: [slot]
            )
        }
        pinChangesSubject.send()
    }

    func delete(itemID: UUID) throws {
        var deletedPinned = false
        try dbPool.write { db in
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

    func search(query: String, limit: Int = 200) throws -> [ClipboardItem] {
        guard !query.isEmpty else { return try recent(limit: limit) }
        let like = "%\(query)%"
        return try dbPool.read { db in
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
        try dbPool.read { db in
            try ClipboardRecord
                .filter(Column("content_hash") == hash)
                .fetchOne(db)?
                .toItem()
        }
    }

    func setPinnedTemplate(slot: Int, template: String?) throws {
        try dbPool.write { db in
            try db.execute(
                sql: "UPDATE clipboard_items SET pinned_template = ? WHERE pinned_slot = ?",
                arguments: [template, slot]
            )
        }
        pinChangesSubject.send()
    }

    private func evictIfNeeded(in db: Database) throws {
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
