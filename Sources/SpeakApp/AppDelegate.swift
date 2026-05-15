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
    private var stt: WhisperKitSTTEngine?
    private var downloadWatchTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let store = SettingsStore()

        let permissions = PermissionsService(provider: SystemPermissionsProvider())
        self.permissionsService = permissions

        let hotkey = RightOptionHotkeyMonitor(combo: store.hotkey)
        let recorder = AVAudioEngineRecorder()
        let stt = WhisperKitSTTEngine(modelName: store.model)
        self.stt = stt
        if !store.autoDetect {
            stt.setLanguage(store.language)
        }
        let injector = ClipboardPasteboardInjector(
            pasteboard: NSPasteboardAdapter(),
            adapter: MacInjectionAdapter()
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

        // Show toast when hotkey is pressed during a download
        Task {
            await coordinator.setHotkeyDuringDownloadHandler {
                Task { @MainActor in
                    ToastPresenter.shared.show("speak is downloading the model. Try again in a moment.")
                }
            }
        }

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
                self?.onboarding?.permissionsStatusChanged(status)
                if status.allGranted, let coordinator = self?.coordinator {
                    Task { await coordinator.start() }
                }
            }
        }

        // Periodic refresh to catch grants/revocations made via System Settings.
        // 2 s while the wizard could be open feels responsive; 5 s would feel
        // sluggish when the user is actively granting permissions.
        permissionsRefreshTask = Task { [weak permissions] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                permissions?.refresh()
            }
        }

        // Show onboarding if any permission is missing; otherwise start and auto-download.
        if permissions.current().allGranted {
            Task { await coordinator.start() }
            startModelDownloadIfNeeded()
        } else {
            showOnboarding()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkey?.stop()
        overlay?.stop()
        permissionsRefreshTask?.cancel()
        downloadWatchTask?.cancel()
    }

    // MARK: - Private

    private func showOnboarding() {
        let service = permissionsService!
        service.refresh()
        let missing = service.current().firstMissing ?? .microphone
        if onboarding == nil {
            let ctrl = OnboardingWindowController(permissionsService: service)
            ctrl.onDone = { [weak self] in
                guard let self else { return }
                if service.current().allGranted {
                    Task { await self.coordinator?.start() }
                    self.menuBar?.setPermissionsNeeded(false)
                    // Auto-download model on first run after onboarding completes.
                    self.startModelDownloadIfNeeded()
                }
            }
            onboarding = ctrl
        }
        onboarding?.show(startingAt: missing)
    }

    /// Kicks off a model download if the model isn't cached yet, and wires progress to the UI.
    private func startModelDownloadIfNeeded() {
        guard let stt, let coordinator, let menuBar, let overlay else { return }

        // Register all stream subscribers BEFORE starting the download so no events are missed.
        let menuBarStream = stt.downloadProgressStream()
        let overlayStream = stt.downloadProgressStream()
        let watchStream = stt.downloadProgressStream()

        menuBar.observeDownloadProgress(menuBarStream)
        overlay.observeDownloadProgress(overlayStream)

        downloadWatchTask?.cancel()
        downloadWatchTask = Task { [weak coordinator] in
            for await event in watchStream {
                switch event {
                case .downloading:
                    await coordinator?.setDownloading(true)
                case .completed:
                    await coordinator?.setDownloading(false)
                    Diagnostics.log("appdelegate: model download complete")
                case .failed(let msg):
                    await coordinator?.setDownloading(false)
                    Diagnostics.log("appdelegate: model download failed: \(msg)")
                    await MainActor.run {
                        ToastPresenter.shared.show("Model download failed. Will use previously cached model if available.")
                    }
                }
            }
        }

        Task {
            await stt.ensureModelDownloaded()
        }
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
