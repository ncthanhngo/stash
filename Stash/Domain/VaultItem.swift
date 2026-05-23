import Foundation

struct VaultItem: Identifiable, Equatable, Sendable, Codable {
    let id: UUID
    var title: String
    var hint: String?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        hint: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.hint = hint
        self.createdAt = createdAt
    }
}
