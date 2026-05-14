import AppKit
import SwiftUI
import SpeakKit
import SpeakSTT

/// Opens (or brings to front) the Settings window.
@MainActor
final class SettingsWindowController: NSWindowController {
    private let vm: SettingsViewModel

    init(
        store: SettingsStore,
        hotkeyMonitor: HotkeyMonitor,
        sttEngine: WhisperKitSTTEngine,
        coordinator: CaptureCoordinator
    ) {
        let vm = SettingsViewModel(
            store: store,
            hotkeyMonitor: hotkeyMonitor,
            sttEngine: sttEngine,
            coordinator: coordinator
        )
        self.vm = vm

        let view = SettingsView(vm: vm)
        let hosting = NSHostingController(rootView: view)

        let window = NSWindow(contentViewController: hosting)
        window.title = "speak Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError() }

    func showSettings() {
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
