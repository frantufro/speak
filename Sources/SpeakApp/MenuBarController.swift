import AppKit
import SpeakKit

@MainActor
final class MenuBarController {
    private let coordinator: CaptureCoordinator
    private var statusItem: NSStatusItem?
    private var pollTask: Task<Void, Never>?
    private var permissionsMenuItem: NSMenuItem?
    private var downloadProgressTask: Task<Void, Never>?
    private var currentDownloadPercent: Int? = nil

    var onPermissionsNeededTapped: (() -> Void)?

    /// Injected after construction so we avoid a circular dependency at init time.
    var settingsWindowController: SettingsWindowController?

    init(coordinator: CaptureCoordinator) {
        self.coordinator = coordinator
    }

    /// Start observing download progress from the engine. Replaces any previous observer.
    func observeDownloadProgress(_ stream: AsyncStream<SpeakKit.DownloadProgress>) {
        downloadProgressTask?.cancel()
        downloadProgressTask = Task { [weak self] in
            for await event in stream {
                guard let self else { break }
                switch event {
                case .downloading(let fraction):
                    self.currentDownloadPercent = Int(fraction * 100)
                    let t = "speak: downloading model… (\(self.currentDownloadPercent!)%)"
                    self.statusItem?.button?.title = t
                    if let stateItem = self.statusItem?.menu?.item(withTag: 1) {
                        stateItem.title = t
                    }
                case .completed, .failed:
                    self.currentDownloadPercent = nil
                }
            }
        }
    }

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "🎙"
        item.button?.toolTip = "speak — hold Right-Option to dictate"

        let menu = NSMenu()

        // State display item (non-interactive)
        let stateItem = NSMenuItem(title: "Idle", action: nil, keyEquivalent: "")
        stateItem.isEnabled = false
        stateItem.tag = 1
        menu.addItem(stateItem)

        let permissionsItem = NSMenuItem(
            title: "Permissions needed",
            action: #selector(permissionsNeededTapped),
            keyEquivalent: ""
        )
        permissionsItem.target = self
        permissionsItem.isHidden = true
        menu.addItem(permissionsItem)
        self.permissionsMenuItem = permissionsItem

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit speak", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        item.menu = menu
        statusItem = item

        pollTask = Task { [weak self] in
            await self?.pollState()
        }
    }

    func setPermissionsNeeded(_ needed: Bool) {
        permissionsMenuItem?.isHidden = !needed
    }

    @objc private func permissionsNeededTapped() {
        onPermissionsNeededTapped?()
    }

    @objc private func openSettings() {
        settingsWindowController?.showSettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func pollState() async {
        var last: CaptureCoordinator.State = .idle
        while !Task.isCancelled {
            let current = await coordinator.state
            // Don't overwrite the menu bar while a download progress update is active.
            if current != last, currentDownloadPercent == nil {
                last = current
                let t = title(for: current)
                statusItem?.button?.title = t
                if let stateItem = statusItem?.menu?.item(withTag: 1) {
                    stateItem.title = current == .idle ? "Idle" : t
                }
            }
            try? await Task.sleep(for: .milliseconds(120))
        }
    }

    private nonisolated func title(for state: CaptureCoordinator.State) -> String {
        switch state {
        case .idle: return "🎙"
        case .recording: return "🔴"
        case .transcribing: return "✨"
        case .injecting: return "⌨️"
        }
    }
}
