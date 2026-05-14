import AppKit
import Combine
import ServiceManagement
import SpeakKit
import SpeakSTT

/// Bridges SettingsView to SettingsStore, HotkeyMonitor, and SMAppService.
/// Must be used on the main actor (it drives UI).
@MainActor
final class SettingsViewModel: ObservableObject {

    static let availableModels: [String] = [
        "openai_whisper-large-v3-v20240930_turbo",
        "openai_whisper-large-v3",
        "openai_whisper-medium",
        "openai_whisper-small",
    ]

    // MARK: – Published properties (drive SwiftUI)

    @Published var hotkey: HotkeyCombo {
        didSet { applyHotkey(hotkey) }
    }
    @Published var isCapturingHotkey = false
    @Published var isRebindBlocked = false

    @Published var model: String {
        didSet { applyModel(model) }
    }

    @Published var launchAtLogin: Bool {
        didSet { applyLaunchAtLogin(launchAtLogin) }
    }

    @Published var autoDetect: Bool {
        didSet { applyAutoDetect(autoDetect) }
    }

    @Published var language: String {
        didSet { applyLanguage(language) }
    }

    // MARK: – Private

    private let store: SettingsStore
    private let hotkeyMonitor: HotkeyMonitor
    private let sttEngine: WhisperKitSTTEngine
    private let coordinator: CaptureCoordinator

    init(
        store: SettingsStore,
        hotkeyMonitor: HotkeyMonitor,
        sttEngine: WhisperKitSTTEngine,
        coordinator: CaptureCoordinator
    ) {
        self.store = store
        self.hotkeyMonitor = hotkeyMonitor
        self.sttEngine = sttEngine
        self.coordinator = coordinator

        // Initialise from persisted values — do NOT trigger didSet observers here.
        self.hotkey = store.hotkey
        self.model = store.model
        self.launchAtLogin = store.launchAtLogin
        self.autoDetect = store.autoDetect
        self.language = store.language
    }

    // MARK: – Apply helpers

    private func applyHotkey(_ combo: HotkeyCombo) {
        Task {
            let state = await coordinator.state
            guard state == .idle else {
                isRebindBlocked = true
                // Revert the UI to what was persisted so the binding stays consistent.
                hotkey = store.hotkey
                return
            }
            isRebindBlocked = false
            store.hotkey = combo
            hotkeyMonitor.rebind(combo)
            Diagnostics.log("settings: hotkey rebound to keyCode=\(combo.keyCode) mask=\(combo.modifierFlags)")
        }
    }

    private func applyModel(_ modelName: String) {
        store.model = modelName
        Diagnostics.log("settings: model set to \(modelName) — will be used on next capture")
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        store.launchAtLogin = enabled
        do {
            if enabled {
                try SMAppService.mainApp.register()
                Diagnostics.log("settings: registered as login item")
            } else {
                try SMAppService.mainApp.unregister()
                Diagnostics.log("settings: unregistered as login item")
            }
        } catch {
            Diagnostics.log("settings: SMAppService error: \(error)")
        }
    }

    private func applyAutoDetect(_ on: Bool) {
        store.autoDetect = on
        if on {
            sttEngine.setLanguage(nil)
        } else {
            sttEngine.setLanguage(store.language)
        }
        Diagnostics.log("settings: autoDetect=\(on)")
    }

    private func applyLanguage(_ code: String) {
        store.language = code
        if !store.autoDetect {
            sttEngine.setLanguage(code)
        }
        Diagnostics.log("settings: language=\(code)")
    }
}
