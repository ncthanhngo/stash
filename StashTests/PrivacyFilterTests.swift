import XCTest
@testable import Stash

final class PrivacyFilterTests: XCTestCase {
    func testDefaultPasswordManagerBlocked() {
        let filter = PrivacyFilter(
            excludedBundleIDs: PrivacyFilter.defaultExcludedBundleIDs,
            concealedTypes: PrivacyFilter.concealedTypes
        )
        XCTAssertFalse(filter.shouldCapture(
            bundleID: "com.1password.1password",
            types: ["public.utf8-plain-text"]
        ))
    }

    func testUserAddedBundleBlocked() {
        let filter = PrivacyFilter(
            excludedBundleIDs: PrivacyFilter.defaultExcludedBundleIDs.union(["com.example.secret"]),
            concealedTypes: PrivacyFilter.concealedTypes
        )
        XCTAssertFalse(filter.shouldCapture(
            bundleID: "com.example.secret",
            types: ["public.utf8-plain-text"]
        ))
    }

    func testConcealedTypeBlocked() {
        let filter = PrivacyFilter(
            excludedBundleIDs: [],
            concealedTypes: PrivacyFilter.concealedTypes
        )
        XCTAssertFalse(filter.shouldCapture(
            bundleID: "com.apple.safari",
            types: ["org.nspasteboard.ConcealedType", "public.utf8-plain-text"]
        ))
    }

    func testConcealedTypeCaseInsensitive() {
        let filter = PrivacyFilter(
            excludedBundleIDs: [],
            concealedTypes: PrivacyFilter.concealedTypes
        )
        XCTAssertFalse(filter.shouldCapture(
            bundleID: nil,
            types: ["ORG.NSPASTEBOARD.CONCEALEDTYPE"]
        ))
    }

    func testNormalCaptureAllowed() {
        let filter = PrivacyFilter(
            excludedBundleIDs: PrivacyFilter.defaultExcludedBundleIDs,
            concealedTypes: PrivacyFilter.concealedTypes
        )
        XCTAssertTrue(filter.shouldCapture(
            bundleID: "com.apple.TextEdit",
            types: ["public.utf8-plain-text"]
        ))
    }

    func testNilBundleAllowedIfTypeOk() {
        let filter = PrivacyFilter(
            excludedBundleIDs: PrivacyFilter.defaultExcludedBundleIDs,
            concealedTypes: PrivacyFilter.concealedTypes
        )
        XCTAssertTrue(filter.shouldCapture(
            bundleID: nil,
            types: ["public.png"]
        ))
    }
}
