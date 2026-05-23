import XCTest
@testable import Stash

final class ClipboardRepositoryTests: XCTestCase {
    func testInsertAndFetchRecent() throws {
        let repo = try InMemoryDatabase.makeRepository()
        try repo.insert(Self.makeItem("a"))
        try repo.insert(Self.makeItem("b"))
        let items = try repo.recent(limit: 10)
        XCTAssertEqual(items.count, 2)
    }

    func testDedupOnHash() throws {
        let repo = try InMemoryDatabase.makeRepository()
        try repo.insert(Self.makeItem("same"))
        try repo.insert(Self.makeItem("same"))
        let items = try repo.recent(limit: 10)
        XCTAssertEqual(items.count, 1)
    }

    func testPinAndUnpin() throws {
        let repo = try InMemoryDatabase.makeRepository()
        let item = Self.makeItem("x")
        try repo.insert(item)
        try repo.pin(itemID: item.id, slot: 3)
        let pinned = try repo.pinned()
        XCTAssertEqual(pinned.count, 1)
        XCTAssertEqual(pinned.first?.pinnedSlot, 3)
        try repo.unpin(slot: 3)
        XCTAssertEqual(try repo.pinned().count, 0)
    }

    func testPinReplacesExistingSlotOccupant() throws {
        let repo = try InMemoryDatabase.makeRepository()
        let first = Self.makeItem("first")
        let second = Self.makeItem("second")
        try repo.insert(first)
        try repo.insert(second)
        try repo.pin(itemID: first.id, slot: 1)
        try repo.pin(itemID: second.id, slot: 1)
        let pinned = try repo.pinned()
        XCTAssertEqual(pinned.count, 1)
        XCTAssertEqual(pinned.first?.id, second.id)
    }

    func testInvalidSlotThrows() throws {
        let repo = try InMemoryDatabase.makeRepository()
        let item = Self.makeItem("a")
        try repo.insert(item)
        XCTAssertThrowsError(try repo.pin(itemID: item.id, slot: 0))
        XCTAssertThrowsError(try repo.pin(itemID: item.id, slot: 10))
    }

    func testEvictionRespectsItemLimit() throws {
        let settings = StorageSettings(maxItems: 5, maxBytes: 1_000_000, autoDeleteAfterDays: 0)
        let repo = try InMemoryDatabase.makeRepository(settings: settings)
        for i in 0..<10 {
            try repo.insert(Self.makeItem("item-\(i)"))
        }
        let items = try repo.recent(limit: 100)
        XCTAssertEqual(items.count, 5)
        XCTAssertEqual(items.first?.textPreview, "item-9")
    }

    func testEvictionPreservesPinnedItems() throws {
        let settings = StorageSettings(maxItems: 3, maxBytes: 1_000_000, autoDeleteAfterDays: 0)
        let repo = try InMemoryDatabase.makeRepository(settings: settings)
        let pinnedItem = Self.makeItem("keep-me")
        try repo.insert(pinnedItem)
        try repo.pin(itemID: pinnedItem.id, slot: 1)
        for i in 0..<10 {
            try repo.insert(Self.makeItem("noise-\(i)"))
        }
        let pinned = try repo.pinned()
        XCTAssertEqual(pinned.count, 1)
        XCTAssertEqual(pinned.first?.id, pinnedItem.id)
    }

    func testFindByHashReturnsItem() throws {
        let repo = try InMemoryDatabase.makeRepository()
        let item = Self.makeItem("findable")
        try repo.insert(item)
        let found = try repo.findByHash("findable")
        XCTAssertEqual(found?.id, item.id)
    }

    func testSearchByTextPreview() throws {
        let repo = try InMemoryDatabase.makeRepository()
        try repo.insert(Self.makeItem("git status"))
        try repo.insert(Self.makeItem("npm install"))
        let results = try repo.search(query: "git", limit: 10)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.textPreview, "git status")
    }

    private static func makeItem(_ text: String) -> ClipboardItem {
        ClipboardItem(
            content: .text(text),
            contentHash: text,
            sourceAppName: "Test"
        )
    }
}
