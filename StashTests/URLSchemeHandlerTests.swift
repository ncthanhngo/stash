import XCTest
@testable import Stash

final class URLSchemeHandlerTests: XCTestCase {
    func testParseOpen() {
        let url = URL(string: "stash://open")!
        XCTAssertEqual(URLSchemeHandler.parse(url), .open)
    }

    func testParsePasteSlot() {
        let url = URL(string: "stash://paste/3")!
        XCTAssertEqual(URLSchemeHandler.parse(url), .paste(slot: 3))
    }

    func testParsePasteInvalidSlot() {
        XCTAssertNil(URLSchemeHandler.parse(URL(string: "stash://paste/0")!))
        XCTAssertNil(URLSchemeHandler.parse(URL(string: "stash://paste/10")!))
        XCTAssertNil(URLSchemeHandler.parse(URL(string: "stash://paste/abc")!))
    }

    func testParseAddText() {
        let url = URL(string: "stash://add?text=hello%20world")!
        XCTAssertEqual(URLSchemeHandler.parse(url), .add(slot: nil, text: "hello world"))
    }

    func testParseAddWithSlot() {
        let url = URL(string: "stash://add?text=secret&slot=5")!
        XCTAssertEqual(URLSchemeHandler.parse(url), .add(slot: 5, text: "secret"))
    }

    func testParseAddRequiresText() {
        XCTAssertNil(URLSchemeHandler.parse(URL(string: "stash://add?slot=5")!))
        XCTAssertNil(URLSchemeHandler.parse(URL(string: "stash://add?text=")!))
    }

    func testParseUnknownScheme() {
        XCTAssertNil(URLSchemeHandler.parse(URL(string: "http://example.com")!))
        XCTAssertNil(URLSchemeHandler.parse(URL(string: "stash://unknown")!))
    }
}
