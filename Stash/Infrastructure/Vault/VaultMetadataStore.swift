import Foundation

final class VaultMetadataStore {
    private let fileURL: URL

    init(directoryURL: URL? = nil) {
        let baseURL = directoryURL ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("Stash", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: baseURL,
            withIntermediateDirectories: true
        )
        self.fileURL = baseURL.appendingPathComponent("vault.plist")
    }

    func load() -> [VaultItem] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? PropertyListDecoder().decode([VaultItem].self, from: data)) ?? []
    }

    func save(_ items: [VaultItem]) throws {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        let data = try encoder.encode(items)
        try data.write(to: fileURL, options: .atomic)
    }
}
