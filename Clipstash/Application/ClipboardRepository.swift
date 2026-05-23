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
    func search(query: String, limit: Int) throws -> [ClipboardItem]
    func findByHash(_ hash: String) throws -> ClipboardItem?
    func setPinnedTemplate(slot: Int, template: String?) throws
    func deleteExpired() throws -> Int
}

enum StorageError: Error, Equatable {
    case invalidSlot(Int)
}
