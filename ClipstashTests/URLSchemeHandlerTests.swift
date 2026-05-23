import XCTest
@testable import Clipstash

final class URLSchemeHandlerTests: XCTestCase {
    func testParseOpen() {
        let url = URL(string: "clipstash://open")!
        XCTAssertEqual(URLSchemeHandler.parse(url), .open)
    }

    func testParsePasteSlot() {
        let url = URL(string: "clipstash://paste/3")!
        XCTAssertEqual(URLSchemeHandler.parse(url), .paste(slot: 3))
    }

    func testParsePasteInvalidSlot() {
        XCTAssertNil(URLSchemeHandler.parse(URL(string: "clipstash://paste/0")!))
        XCTAssertNil(URLSchemeHandler.parse(URL(string: "clipstash://paste/10")!))
        XCTAssertNil(URLSchemeHandler.parse(URL(string: "clipstash://paste/abc")!))
    }

    func testParseAddText() {
        let url = URL(string: "clipstash://add?text=hello%20world")!
        XCTAssertEqual(URLSchemeHandler.parse(url), .add(slot: nil, text: "hello world"))
    }

    func testParseAddWithSlot() {
        let url = URL(string: "clipstash://add?text=secret&slot=5")!
        XCTAssertEqual(URLSchemeHandler.parse(url), .add(slot: 5, text: "secret"))
    }

    func testParseAddRequiresText() {
        XCTAssertNil(URLSchemeHandler.parse(URL(string: "clipstash://add?slot=5")!))
        XCTAssertNil(URLSchemeHandler.parse(URL(string: "clipstash://add?text=")!))
    }

    func testParseUnknownScheme() {
        XCTAssertNil(URLSchemeHandler.parse(URL(string: "http://example.com")!))
        XCTAssertNil(URLSchemeHandler.parse(URL(string: "clipstash://unknown")!))
    }
}
