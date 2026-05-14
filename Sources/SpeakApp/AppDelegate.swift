import AppKit
import SpeakKit
import SpeakPlatform
import SpeakSTT

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: CaptureCoordinator?
    private var hotkey: RightOptionHotkeyMonitor?
    private var menuBar: MenuBarController?
    private var settings: SettingsWindowController?
    private var overlay: OverlayPresenter?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let store = SettingsStore()

        let hotkey = RightOptionHotkeyMonitor(combo: store.hotkey)
        let recorder = AVAudioEngineRecorder()
        let stt = WhisperKitSTTEngine(modelName: store.model)
        // Apply persisted language setting.
        if !store.autoDetect {
            stt.setLanguage(store.language)
        }
        let injector = ClipboardPasteboardInjector(
            pasteboard: NSPasteboardAdapter(),
            keystroke: CGEventKeystrokeSynthesizer(),
            secureInput: MacSecureInputDetector()
        )

        let coordinator = CaptureCoordinator(
            hotkey: hotkey,
            recorder: recorder,
            stt: stt,
            injector: injector
        )
        self.coordinator = coordinator
        self.hotkey = hotkey

        let menuBar = MenuBarController(coordinator: coordinator)
        menuBar.install()
        self.menuBar = menuBar

        let settingsWC = SettingsWindowController(
            store: store,
            hotkeyMonitor: hotkey,
            sttEngine: stt,
            coordinator: coordinator
        )
        self.settings = settingsWC
        menuBar.settingsWindowController = settingsWC

        let overlay = OverlayPresenter(coordinator: coordinator)
        overlay.start()
        self.overlay = overlay

        Task { await coordinator.start() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkey?.stop()
        overlay?.stop()
    }
}
