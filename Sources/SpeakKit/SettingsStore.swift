import Foundation

/// Typed, testable wrapper around `UserDefaults` for all user-configurable settings.
///
/// Pass a custom `UserDefaults` (e.g. `UserDefaults(suiteName: "test")`) in tests
/// for isolation.
public final class SettingsStore: @unchecked Sendable {

    // MARK: – Keys

    public enum Key {
        public static let hotkey       = "speak.hotkey"
        public static let model        = "speak.model"
        public static let launchAtLogin = "speak.launchAtLogin"
        public static let autoDetect   = "speak.autoDetect"
        public static let language     = "speak.language"
    }

    // MARK: – Default values

    public static let defaultModel = "openai_whisper-large-v3-v20240930_turbo"

    // MARK: – Storage

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: – Hotkey

    /// The active hotkey combo. Defaults to right-Option.
    public var hotkey: HotkeyCombo {
        get {
            guard
                let data = defaults.data(forKey: Key.hotkey),
                let combo = try? JSONDecoder().decode(HotkeyCombo.self, from: data)
            else {
                return .rightOption
            }
            return combo
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Key.hotkey)
            }
        }
    }

    // MARK: – Model

    /// The WhisperKit model name. Defaults to large-v3-turbo.
    public var model: String {
        get { defaults.string(forKey: Key.model) ?? Self.defaultModel }
        set { defaults.set(newValue, forKey: Key.model) }
    }

    // MARK: – Launch at login

    /// Whether the app registers itself as a login item. Defaults to false.
    public var launchAtLogin: Bool {
        get { defaults.bool(forKey: Key.launchAtLogin) }
        set { defaults.set(newValue, forKey: Key.launchAtLogin) }
    }

    // MARK: – Language

    /// Whether auto-detect language is enabled. Defaults to true.
    public var autoDetect: Bool {
        get {
            guard defaults.object(forKey: Key.autoDetect) != nil else { return true }
            return defaults.bool(forKey: Key.autoDetect)
        }
        set { defaults.set(newValue, forKey: Key.autoDetect) }
    }

    /// The manually chosen language code when `autoDetect` is false. Defaults to "en".
    public var language: String {
        get { defaults.string(forKey: Key.language) ?? "en" }
        set { defaults.set(newValue, forKey: Key.language) }
    }
}
