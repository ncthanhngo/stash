import XCTest
@testable import Clipstash

final class TemplateRendererTests: XCTestCase {
    private let fixedDate: Date = {
        var components = DateComponents()
        components.year = 2026; components.month = 5; components.day = 23
        components.hour = 14; components.minute = 30
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components)!
    }()

    func testPlainLiteralPassesThrough() {
        let result = TemplateRenderer.render("Hello, world", context: makeContext())
        XCTAssertEqual(result.text, "Hello, world")
        XCTAssertEqual(result.cursorOffsetFromEnd, 0)
    }

    func testClipboardVariableInterpolated() {
        let result = TemplateRenderer.render(
            "Hello {{clipboard}}",
            context: makeContext(clipboard: "world")
        )
        XCTAssertEqual(result.text, "Hello world")
    }

    func testDateDefaultFormat() {
        let result = TemplateRenderer.render("{{date}}", context: makeContext())
        XCTAssertEqual(result.text, "2026-05-23")
    }

    func testDateCustomFormat() {
        let result = TemplateRenderer.render(
            "{{date:dd/MM/yyyy}}",
            context: makeContext()
        )
        XCTAssertEqual(result.text, "23/05/2026")
    }

    func testUnknownVariablePassesThrough() {
        let result = TemplateRenderer.render("{{foo}}", context: makeContext())
        XCTAssertEqual(result.text, "{{foo}}")
    }

    func testCursorOffsetComputed() {
        let result = TemplateRenderer.render(
            "Dear $|$,",
            context: makeContext()
        )
        XCTAssertEqual(result.text, "Dear ,")
        XCTAssertEqual(result.cursorOffsetFromEnd, 1)
    }

    func testOnlyFirstCursorCounts() {
        let result = TemplateRenderer.render(
            "$|$ then $|$ end",
            context: makeContext()
        )
        XCTAssertEqual(result.text, " then $|$ end")
        XCTAssertEqual(result.cursorOffsetFromEnd, 13)
    }

    func testEmptyClipboardRendersEmpty() {
        let result = TemplateRenderer.render(
            "Hi {{clipboard}}!",
            context: makeContext(clipboard: nil)
        )
        XCTAssertEqual(result.text, "Hi !")
    }

    private func makeContext(clipboard: String? = nil) -> RenderContext {
        RenderContext(
            date: fixedDate,
            clipboard: clipboard,
            uuidProvider: { "00000000-0000-0000-0000-000000000000" }
        )
    }
}
