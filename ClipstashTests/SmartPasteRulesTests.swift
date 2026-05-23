import XCTest
@testable import Clipstash

final class SmartPasteRulesTests: XCTestCase {
    func testAnsiStripper() {
        let input = "\u{1B}[31mHello\u{1B}[0m World\u{1B}[1;32m!"
        XCTAssertEqual(AnsiStripper.strip(input), "Hello World!")
    }

    func testAnsiStripperNoOp() {
        XCTAssertEqual(AnsiStripper.strip("plain text"), "plain text")
    }

    func testUniformDedentSimple() {
        let input = "    line1\n    line2\n    line3"
        XCTAssertEqual(UniformDedent.dedent(input), "line1\nline2\nline3")
    }

    func testUniformDedentMixed() {
        let input = "    line1\n        nested\n    line3"
        XCTAssertEqual(UniformDedent.dedent(input), "line1\n    nested\nline3")
    }

    func testUniformDedentSkipsBlankLines() {
        let input = "    a\n\n    b"
        XCTAssertEqual(UniformDedent.dedent(input), "a\n\nb")
    }

    func testMarkdownBoldToMrkdwn() {
        XCTAssertEqual(MarkdownToMrkdwn.convert("**hello**"), "*hello*")
        XCTAssertEqual(MarkdownToMrkdwn.convert("a **b** c **d**"), "a *b* c *d*")
    }

    func testRegistryAppliesMatchingRule() {
        let registry = SmartPasteRegistry()
        let content = CapturedContent.text("\u{1B}[31mred\u{1B}[0m")
        let out = registry.apply(content: content, frontmostBundleID: "com.apple.Terminal")
        if case .text(let s) = out {
            XCTAssertEqual(s, "red")
        } else {
            XCTFail("expected text")
        }
    }

    func testRegistryPassThroughForUnknownApp() {
        let registry = SmartPasteRegistry()
        let content = CapturedContent.text("\u{1B}[31mred\u{1B}[0m")
        let out = registry.apply(content: content, frontmostBundleID: "com.apple.TextEdit")
        if case .text(let s) = out {
            XCTAssertEqual(s, "\u{1B}[31mred\u{1B}[0m")
        } else {
            XCTFail("expected text")
        }
    }
}
