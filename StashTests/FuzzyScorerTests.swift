import XCTest
@testable import Stash

final class FuzzyScorerTests: XCTestCase {
    func testEmptyQueryReturnsAllItems() {
        let items = [Self.makeItem("hello"), Self.makeItem("world")]
        let result = FuzzyScorer.rank(items, query: "")
        XCTAssertEqual(result.count, 2)
    }

    func testSubsequenceMatch() {
        let items = [
            Self.makeItem("git status"),
            Self.makeItem("git push"),
            Self.makeItem("npm install")
        ]
        let result = FuzzyScorer.rank(items, query: "git")
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.allSatisfy { ($0.item.textPreview ?? "").contains("git") })
    }

    func testNonMatchExcluded() {
        let items = [Self.makeItem("hello world")]
        let result = FuzzyScorer.rank(items, query: "xyz")
        XCTAssertEqual(result.count, 0)
    }

    func testRecencyBoostFavoursNewerItem() {
        let now = Date()
        let recent = Self.makeItem("git status", createdAt: now)
        let old = Self.makeItem("git status", createdAt: now.addingTimeInterval(-7 * 86_400))
        let result = FuzzyScorer.rank([old, recent], query: "git")
        XCTAssertEqual(result.first?.item.id, recent.id)
    }

    func testWordStartBonus() {
        let items = [
            Self.makeItem("install git"),
            Self.makeItem("argument")
        ]
        let result = FuzzyScorer.rank(items, query: "g")
        XCTAssertEqual(result.first?.item.textPreview, "install git")
    }

    // MARK: - helpers

    private static func makeItem(_ text: String, createdAt: Date = Date()) -> ClipboardItem {
        ClipboardItem(
            content: .text(text),
            contentHash: text,
            sourceAppName: "Test",
            createdAt: createdAt
        )
    }
}
