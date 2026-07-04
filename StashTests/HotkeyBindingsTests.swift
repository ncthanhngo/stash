import XCTest
@testable import Stash

@MainActor
final class HotkeyBindingsTests: XCTestCase {
    private let suiteName = "stash.tests.hotkeybindings"

    private func makeSuite() -> UserDefaults {
        let s = UserDefaults(suiteName: suiteName)!
        s.removePersistentDomain(forName: suiteName)
        return s
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testDefaultsMatchLegacyValues() {
        let bindings = HotkeyBindings(defaults: makeSuite())
        XCTAssertEqual(bindings.combo(for: .captureScreenshotCrop).display, "⇧⌘S")
        XCTAssertEqual(bindings.combo(for: .pasteLatestPlainText).display, "⇧⌘V")
        XCTAssertEqual(bindings.combo(for: .togglePopover).display, "⇧⌘C")
        // Apple HIG order: ⌃ ⌥ ⇧ ⌘ (Control, Option, Shift, Command).
        XCTAssertEqual(bindings.combo(for: .togglePrivacyMode).display, "⌥⇧⌘P")
        for n in 1...9 {
            XCTAssertEqual(bindings.combo(for: .pasteSlot(n)).display, "⌥\(n)")
        }
    }

    func testKeyComboDisabledSentinel() {
        XCTAssertTrue(KeyCombo.disabled.isDisabled)
        XCTAssertEqual(KeyCombo.disabled.display, "Disabled")
    }

    func testUpdateAndPersistAcrossInstances() throws {
        let suite = makeSuite()
        let first = HotkeyBindings(defaults: suite)
        let custom = KeyCombo(
            keyCode: 0x12,
            modifierFlagsRaw: KeyCombo.ModifierBits.control,
            keyDisplay: "1"
        )
        try first.update(custom, for: .pasteSlot(1))

        let second = HotkeyBindings(defaults: suite)
        XCTAssertEqual(second.combo(for: .pasteSlot(1)), custom)
    }

    func testResetRestoresDefault() throws {
        let suite = makeSuite()
        let bindings = HotkeyBindings(defaults: suite)
        let custom = KeyCombo(
            keyCode: 0x12,
            modifierFlagsRaw: KeyCombo.ModifierBits.control,
            keyDisplay: "1"
        )
        try bindings.update(custom, for: .pasteSlot(1))
        bindings.reset(.pasteSlot(1))
        XCTAssertEqual(bindings.combo(for: .pasteSlot(1)).display, "⌥1")
    }

    func testCollisionDetected() throws {
        let bindings = HotkeyBindings(defaults: makeSuite())
        // Try to bind paste-slot-1 to default of paste-slot-2 → must throw.
        let slot2Default = HotkeyAction.pasteSlot(2).defaultCombo
        XCTAssertThrowsError(
            try bindings.update(slot2Default, for: .pasteSlot(1))
        ) { error in
            guard case HotkeyBindings.BindingError.collision(let other) = error else {
                return XCTFail("expected .collision, got \(error)")
            }
            XCTAssertEqual(other, .pasteSlot(2))
        }
    }

    func testLegacyScreenshotKeyMigrates() throws {
        let suite = makeSuite()
        let legacy = KeyCombo(
            keyCode: 0x35,
            modifierFlagsRaw: KeyCombo.ModifierBits.control | KeyCombo.ModifierBits.shift,
            keyDisplay: "Esc"
        )
        suite.set(try JSONEncoder().encode(legacy), forKey: "stash.hotkey.screenshot")

        let bindings = HotkeyBindings(defaults: suite)
        XCTAssertEqual(bindings.combo(for: .captureScreenshotCrop), legacy)
        XCTAssertNil(suite.data(forKey: "stash.hotkey.screenshot"))
    }
}
