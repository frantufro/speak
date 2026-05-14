import XCTest
@testable import SpeakKit

final class SettingsStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var store: SettingsStore!

    override func setUp() {
        super.setUp()
        let suiteName = "speak.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        store = SettingsStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: defaults.dictionaryRepresentation().keys.joined())
        super.tearDown()
    }

    // MARK: – Hotkey

    func test_hotkey_defaultIsRightOption() {
        XCTAssertEqual(store.hotkey, .rightOption)
    }

    func test_hotkey_roundTrip() {
        let combo = HotkeyCombo(keyCode: 49, modifierFlags: 0x0000_0002)
        store.hotkey = combo
        XCTAssertEqual(store.hotkey, combo)
    }

    func test_hotkey_persistsKeyCode() {
        store.hotkey = HotkeyCombo(keyCode: 36, modifierFlags: 0)
        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.hotkey.keyCode, 36)
    }

    func test_hotkey_persistsModifierFlags() {
        store.hotkey = HotkeyCombo(keyCode: 61, modifierFlags: 0x0000_0040)
        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.hotkey.modifierFlags, 0x0000_0040)
    }

    // MARK: – Model

    func test_model_defaultIsLargeV3Turbo() {
        XCTAssertEqual(store.model, SettingsStore.defaultModel)
    }

    func test_model_roundTrip() {
        store.model = "openai_whisper-medium"
        XCTAssertEqual(store.model, "openai_whisper-medium")
    }

    func test_model_persists() {
        store.model = "openai_whisper-small"
        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.model, "openai_whisper-small")
    }

    // MARK: – Launch at login

    func test_launchAtLogin_defaultIsFalse() {
        XCTAssertFalse(store.launchAtLogin)
    }

    func test_launchAtLogin_roundTrip() {
        store.launchAtLogin = true
        XCTAssertTrue(store.launchAtLogin)
        store.launchAtLogin = false
        XCTAssertFalse(store.launchAtLogin)
    }

    func test_launchAtLogin_persists() {
        store.launchAtLogin = true
        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertTrue(reloaded.launchAtLogin)
    }

    // MARK: – Auto-detect

    func test_autoDetect_defaultIsTrue() {
        XCTAssertTrue(store.autoDetect)
    }

    func test_autoDetect_roundTrip() {
        store.autoDetect = false
        XCTAssertFalse(store.autoDetect)
        store.autoDetect = true
        XCTAssertTrue(store.autoDetect)
    }

    func test_autoDetect_persists() {
        store.autoDetect = false
        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertFalse(reloaded.autoDetect)
    }

    // MARK: – Language

    func test_language_defaultIsEnglish() {
        XCTAssertEqual(store.language, "en")
    }

    func test_language_roundTrip() {
        store.language = "es"
        XCTAssertEqual(store.language, "es")
    }

    func test_language_persists() {
        store.language = "es"
        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.language, "es")
    }
}
