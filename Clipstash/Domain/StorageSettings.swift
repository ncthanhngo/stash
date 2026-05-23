import Foundation

struct StorageSettings: Equatable, Sendable {
    var maxItems: Int
    var maxBytes: Int

    static let defaults = StorageSettings(
        maxItems: 500,
        maxBytes: 100 * 1024 * 1024
    )
}
