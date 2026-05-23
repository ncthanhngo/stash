import XCTest
@testable import Clipstash

final class TemplateTokenizerTests: XCTestCase {
    func testLiteralOnly() {
        XCTAssertEqual(TemplateTokenizer.tokenize("plain"), [.literal("plain")])
    }

    func testSingleVariable() {
        XCTAssertEqual(
            TemplateTokenizer.tokenize("{{date}}"),
            [.variable(name: "date", arg: nil)]
        )
    }

    func testVariableWithArg() {
        XCTAssertEqual(
            TemplateTokenizer.tokenize("{{date:yyyy-MM-dd}}"),
            [.variable(name: "date", arg: "yyyy-MM-dd")]
        )
    }

    func testMixedLiteralAndVariable() {
        XCTAssertEqual(
            TemplateTokenizer.tokenize("Hi {{clipboard}}!"),
            [
                .literal("Hi "),
                .variable(name: "clipboard", arg: nil),
                .literal("!")
            ]
        )
    }

    func testCursorMarker() {
        XCTAssertEqual(
            TemplateTokenizer.tokenize("a$|$b"),
            [.literal("a"), .cursor, .literal("b")]
        )
    }

    func testSecondCursorDemotedToLiteral() {
        let tokens = TemplateTokenizer.tokenize("$|$ and $|$")
        XCTAssertEqual(tokens, [.cursor, .literal(" and "), .literal("$|$")])
    }

    func testUnclosedBraceTreatedAsLiteral() {
        let tokens = TemplateTokenizer.tokenize("{{unfinished")
        XCTAssertEqual(tokens, [.literal("{{unfinished")])
    }
}
