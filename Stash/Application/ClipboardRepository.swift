import Foundation
import Combine

protocol ClipboardRepository: AnyObject {
    var pinChanges: AnyPublisher<Void, Never> { get }

    func insert(_ item: ClipboardItem) throws
    func recent(limit: Int) throws -> [ClipboardItem]
    func pinned() throws -> [ClipboardItem]
    func pin(itemID: UUID, slot: Int) throws
    func unpin(slot: Int) throws
    func delete(itemID: UUID) throws

    /// Delete every unpinned history row, leaving the 9 pinned slots intact.
    func clearHistory() throws
    func search(query: String, limit: Int) throws -> [ClipboardItem]
    func findByHash(_ hash: String) throws -> ClipboardItem?
    func setPinnedTemplate(slot: Int, template: String?) throws
    func deleteExpired() throws -> Int
    func recordPaste(itemID: UUID) throws
    func topPasted(limit: Int) throws -> [ClipboardItem]

    /// Re-run eviction with the latest storage settings. Called after the user
    /// edits limits in Settings so changes apply without an app restart.
    func applyLimitsNow() throws

    /// Read-only access to the underlying SQLite file for export.
    func backupSQLite() throws -> Data

    /// Replace the entire database contents with the given SQLite blob.
    /// Used by history-bundle import (replace strategy).
    func restoreSQLite(from data: Data) throws
}

enum StorageError: Error, Equatable {
    case invalidSlot(Int)
}
