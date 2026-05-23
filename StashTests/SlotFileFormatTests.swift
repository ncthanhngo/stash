import XCTest
@testable import Stash

final class SlotFileFormatTests: XCTestCase {
    private var tempFolder: URL!

    override func setUpWithError() throws {
        tempFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("stash-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempFolder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempFolder)
    }

    func testTextRoundTrip() throws {
        let item = ClipboardItem(
            content: .text("hello"),
            contentHash: "h",
            sourceAppName: "Notes"
        )
        try SlotFileFormat.write(item: item, slot: 1, folder: tempFolder, deviceID: "dev-A")
        let remotes = SlotFileFormat.readAll(from: tempFolder)
        XCTAssertEqual(remotes.count, 1)
        XCTAssertEqual(remotes[0].slot, 1)
        if case .text(let s) = remotes[0].content {
            XCTAssertEqual(s, "hello")
        } else {
            XCTFail("expected text content")
        }
        XCTAssertEqual(remotes[0].updatedBy, "dev-A")
    }

    func testImageRoundTrip() throws {
        let pngBytes = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        let item = ClipboardItem(
            content: .image(data: pngBytes, thumbnail: Data()),
            contentHash: "h"
        )
        try SlotFileFormat.write(item: item, slot: 3, folder: tempFolder, deviceID: "dev-B")
        let remotes = SlotFileFormat.readAll(from: tempFolder)
        XCTAssertEqual(remotes.count, 1)
        if case .image(let data, _) = remotes[0].content {
            XCTAssertEqual(data, pngBytes)
        } else {
            XCTFail("expected image content")
        }
    }

    func testRemoveClearsAllSlotFiles() throws {
        let item = ClipboardItem(content: .text("x"), contentHash: "h")
        try SlotFileFormat.write(item: item, slot: 5, folder: tempFolder, deviceID: "dev")
        SlotFileFormat.remove(slot: 5, folder: tempFolder)
        XCTAssertEqual(SlotFileFormat.readAll(from: tempFolder).count, 0)
    }

    func testFileURLRoundTrip() throws {
        let item = ClipboardItem(
            content: .fileURLs(["/tmp/a.txt", "/tmp/b.txt"]),
            contentHash: "h"
        )
        try SlotFileFormat.write(item: item, slot: 2, folder: tempFolder, deviceID: "dev")
        let remotes = SlotFileFormat.readAll(from: tempFolder)
        if case .fileURLs(let paths) = remotes[0].content {
            XCTAssertEqual(paths, ["/tmp/a.txt", "/tmp/b.txt"])
        } else {
            XCTFail("expected fileURLs content")
        }
    }
}
