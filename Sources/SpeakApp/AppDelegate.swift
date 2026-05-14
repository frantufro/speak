import AppKit
import SpeakKit
import SpeakPlatform
import SpeakSTT

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: CaptureCoordinator?
    private var hotkey: RightOptionHotkeyMonitor?
    private var menuBar: MenuBarController?
    private var overlay: OverlayPresenter?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let hotkey = RightOptionHotkeyMonitor()
        let recorder = AVAudioEngineRecorder()
        let stt = WhisperKitSTTEngine()
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
