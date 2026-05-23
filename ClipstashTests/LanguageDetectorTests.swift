import XCTest
@testable import Clipstash

final class LanguageDetectorTests: XCTestCase {
    func testDetectJSON() {
        XCTAssertEqual(LanguageDetector.detect("{\"a\": 1, \"b\": [1,2]}"), .json)
        XCTAssertEqual(LanguageDetector.detect("[1,2,3]"), .json)
    }

    func testDetectBashShebang() {
        XCTAssertEqual(LanguageDetector.detect("#!/bin/bash\necho hi"), .bash)
        XCTAssertEqual(LanguageDetector.detect("#!/usr/bin/env bash\nset -e"), .bash)
    }

    func testDetectSwift() {
        let code = "import Foundation\nfunc hello() {\n  let x = 1\n  print(x)\n}"
        XCTAssertEqual(LanguageDetector.detect(code), .swift)
    }

    func testDetectPython() {
        let code = "import os\ndef hello():\n    print('hi')"
        XCTAssertEqual(LanguageDetector.detect(code), .python)
    }

    func testDetectGo() {
        let code = "package main\n\nimport (\n  \"fmt\"\n)\n\nfunc main() { fmt.Println(\"hi\") }"
        XCTAssertEqual(LanguageDetector.detect(code), .go)
    }

    func testDetectRust() {
        let code = "fn main() {\n    let mut x = 0;\n}"
        XCTAssertEqual(LanguageDetector.detect(code), .rust)
    }

    func testDetectJavaScript() {
        XCTAssertEqual(LanguageDetector.detect("const x = () => 1;"), .javascript)
        XCTAssertEqual(LanguageDetector.detect("function hello() { return 1; }"), .javascript)
    }

    func testPlainProseNotDetected() {
        XCTAssertEqual(LanguageDetector.detect("Hello, this is just a sentence."), .plain)
    }

    func testEmptyIsPlain() {
        XCTAssertEqual(LanguageDetector.detect(""), .plain)
        XCTAssertEqual(LanguageDetector.detect("   "), .plain)
    }
}
