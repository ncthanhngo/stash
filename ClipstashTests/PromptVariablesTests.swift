import XCTest
@testable import Clipstash

final class PromptVariablesTests: XCTestCase {
    func testPromptLabelsExtracted() {
        let template = "Hi {{prompt:Name}}, your ticket #{{prompt:Ticket ID}} is ready."
        let labels = TemplateRenderer.promptLabels(in: template)
        XCTAssertEqual(labels, ["Name", "Ticket ID"])
    }

    func testPromptLabelsDedupeKeepingOrder() {
        let template = "{{prompt:A}} and again {{prompt:A}} then {{prompt:B}}"
        let labels = TemplateRenderer.promptLabels(in: template)
        XCTAssertEqual(labels, ["A", "B"])
    }

    func testPromptRenderUsesAnswers() {
        let context = RenderContext(
            date: Date(),
            clipboard: nil,
            promptAnswers: ["Name": "Tom"]
        )
        let result = TemplateRenderer.render("Hi {{prompt:Name}}!", context: context)
        XCTAssertEqual(result.text, "Hi Tom!")
    }

    func testEmptyAnswerSubstitutesEmpty() {
        let context = RenderContext(date: Date(), clipboard: nil, promptAnswers: [:])
        let result = TemplateRenderer.render("Hi {{prompt:Name}}!", context: context)
        XCTAssertEqual(result.text, "Hi !")
    }

    func testTemplateWithoutPromptsReturnsEmpty() {
        let labels = TemplateRenderer.promptLabels(in: "Hi {{clipboard}}")
        XCTAssertEqual(labels, [])
    }
}
