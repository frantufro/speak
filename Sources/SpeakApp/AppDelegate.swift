import AppKit
import SpeakKit
import SpeakPlatform
import SpeakSTT

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: CaptureCoordinator?
    private var hotkey: RightOptionHotkeyMonitor?
    private var menuBar: MenuBarController?
    private var settings: SettingsWindowController?
    private var overlay: OverlayPresenter?
    private var permissionsService: PermissionsService?
    private var onboarding: OnboardingWindowController?
    private var permissionsRefreshTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let store = SettingsStore()

        let permissions = PermissionsService(provider: SystemPermissionsProvider())
        self.permissionsService = permissions

        let hotkey = RightOptionHotkeyMonitor(combo: store.hotkey)
        let recorder = AVAudioEngineRecorder()
        let stt = WhisperKitSTTEngine(modelName: store.model)
        if !store.autoDetect {
            stt.setLanguage(store.language)
        }
        let injector = ClipboardPasteboardInjector(
            pasteboard: NSPasteboardAdapter(),
            keystroke: CGEventKeystrokeSynthesizer(),
            secureInput: MacSecureInputDetector()
        )

        // Wire secure-input toast
        let toastBridge = ToastBridge()
        injector.secureInputToastDelegate = toastBridge

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
        menuBar.onPermissionsNeededTapped = { [weak self] in
            self?.showOnboarding()
        }
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

        // Permissions change notifications (always delivered on main)
        permissions.statusDidChange = { [weak self] status in
            Task { @MainActor [weak self] in
                self?.menuBar?.setPermissionsNeeded(!status.allGranted)
            }
        }

        // Periodic refresh to catch runtime revocations (every 5 s)
        permissionsRefreshTask = Task { [weak permissions] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                permissions?.refresh()
            }
        }

        // Show onboarding if any permission is missing; otherwise start.
        if permissions.current().allGranted {
            Task { await coordinator.start() }
        } else {
            showOnboarding()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkey?.stop()
        overlay?.stop()
        permissionsRefreshTask?.cancel()
    }

    // MARK: - Private

    private func showOnboarding() {
        let service = permissionsService!
        let missing = service.current().firstMissing ?? .microphone
        if onboarding == nil {
            let ctrl = OnboardingWindowController(permissionsService: service)
            ctrl.onDone = { [weak self] in
                guard let self else { return }
                if service.current().allGranted {
                    Task { await self.coordinator?.start() }
                    self.menuBar?.setPermissionsNeeded(false)
                }
            }
            onboarding = ctrl
        }
        onboarding?.show(startingAt: missing)
    }
}

// MARK: - Toast bridge

/// Thin Sendable bridge so the SpeakKit injector (no AppKit dep) can trigger
/// the AppKit toast without a direct import.
private final class ToastBridge: SecureInputToastDelegate, @unchecked Sendable {
    func secureInputDidBlockInjection() {
        Task { @MainActor in
            ToastPresenter.shared.show("speak won't dictate into secure fields.")
        }
    }
}
