import XCTest
@testable import Stash

final class TextTransformTests: XCTestCase {
    func testUrlEncodeDecode() {
        XCTAssertEqual(try TextTransform.urlEncode.apply("hello world").get(), "hello%20world")
        XCTAssertEqual(try TextTransform.urlDecode.apply("hello%20world").get(), "hello world")
    }

    func testBase64Roundtrip() {
        let encoded = try? TextTransform.base64Encode.apply("hello").get()
        XCTAssertEqual(encoded, "aGVsbG8=")
        let decoded = try? TextTransform.base64Decode.apply("aGVsbG8=").get()
        XCTAssertEqual(decoded, "hello")
    }

    func testBase64InvalidFails() {
        if case .failure = TextTransform.base64Decode.apply("***") {
            // expected
        } else {
            XCTFail("expected failure")
        }
    }

    func testJsonPrettyMinify() {
        let pretty = try? TextTransform.jsonPretty.apply("{\"a\":1,\"b\":2}").get()
        XCTAssertNotNil(pretty)
        XCTAssertTrue(pretty!.contains("\n"))
        let minified = try? TextTransform.jsonMinify.apply(pretty!).get()
        XCTAssertEqual(minified, "{\"a\":1,\"b\":2}")
    }

    func testJsonInvalidFails() {
        if case .failure = TextTransform.jsonPretty.apply("not json") {
            // expected
        } else {
            XCTFail("expected failure")
        }
    }

    func testCaseConversions() {
        XCTAssertEqual(try TextTransform.camelCase.apply("hello_world test").get(), "helloWorldTest")
        XCTAssertEqual(try TextTransform.snakeCase.apply("helloWorld Test").get(), "hello_world_test")
        XCTAssertEqual(try TextTransform.kebabCase.apply("HelloWorld").get(), "hello-world")
    }

    func testHashes() {
        XCTAssertEqual(try TextTransform.sha256.apply("").get(),
                       "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        XCTAssertEqual(try TextTransform.md5.apply("").get(),
                       "d41d8cd98f00b204e9800998ecf8427e")
    }

    func testHtmlEncodeDecode() {
        XCTAssertEqual(try TextTransform.htmlEncode.apply("<a>&b</a>").get(),
                       "&lt;a&gt;&amp;b&lt;/a&gt;")
        XCTAssertEqual(try TextTransform.htmlDecode.apply("&lt;a&gt;").get(), "<a>")
    }

    func testTrim() {
        XCTAssertEqual(try TextTransform.trim.apply("  hi \n").get(), "hi")
    }

    func testUnescape() {
        XCTAssertEqual(try TextTransform.unescapeJSString.apply("a\\nb\\t").get(), "a\nb\t")
    }
}
