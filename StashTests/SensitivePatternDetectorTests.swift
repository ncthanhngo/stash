import XCTest
@testable import Stash

final class SensitivePatternDetectorTests: XCTestCase {
    func testValidCreditCardDetected() {
        // Test card numbers (Luhn-valid): 4111111111111111 is Visa test
        XCTAssertEqual(SensitivePatternDetector.detect(in: "4111111111111111"), .creditCard)
        XCTAssertEqual(SensitivePatternDetector.detect(in: "4111 1111 1111 1111"), .creditCard)
    }

    func testInvalidLuhnNotCreditCard() {
        XCTAssertNotEqual(SensitivePatternDetector.detect(in: "1234567890123456"), .creditCard)
    }

    func testOTPDetected() {
        XCTAssertEqual(SensitivePatternDetector.detect(in: "123456"), .otp)
        XCTAssertEqual(SensitivePatternDetector.detect(in: "9876"), .otp)
    }

    func testJWTDetected() {
        let jwt = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMifQ.signature_part_here"
        XCTAssertEqual(SensitivePatternDetector.detect(in: jwt), .jwt)
    }

    func testAPIKeyDetected() {
        XCTAssertEqual(SensitivePatternDetector.detect(in: "sk_live_abcdefghijklmnopqrstuv"), .apiKey)
        XCTAssertEqual(SensitivePatternDetector.detect(in: "ghp_abcdefghijklmnopqrstuvwxyz0123456789"), .apiKey)
    }

    func testRegularTextNotDetected() {
        XCTAssertNil(SensitivePatternDetector.detect(in: "Hello, world"))
        XCTAssertNil(SensitivePatternDetector.detect(in: "https://example.com/path"))
    }

    func testEmptyReturnsNil() {
        XCTAssertNil(SensitivePatternDetector.detect(in: ""))
        XCTAssertNil(SensitivePatternDetector.detect(in: "   "))
    }

    func testDefaultTTLs() {
        XCTAssertEqual(SensitiveKind.otp.defaultTTL, 60)
        XCTAssertEqual(SensitiveKind.creditCard.defaultTTL, 300)
        XCTAssertEqual(SensitiveKind.jwt.defaultTTL, 600)
        XCTAssertEqual(SensitiveKind.apiKey.defaultTTL, 600)
    }
}
