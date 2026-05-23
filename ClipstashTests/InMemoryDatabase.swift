import Foundation
import GRDB
@testable import Clipstash

enum InMemoryDatabase {
    static func makeRepository(settings: StorageSettings = .defaults) throws -> GRDBClipboardRepository {
        let queue = try DatabaseQueue()
        try Migrations.migrator.migrate(queue)
        return GRDBClipboardRepository(writer: queue, settings: settings)
    }
}
