import AppKit
import SpeakKit

@MainActor
final class MenuBarController {
    private let coordinator: CaptureCoordinator
    private var statusItem: NSStatusItem?
    private var pollTask: Task<Void, Never>?
    private var permissionsMenuItem: NSMenuItem?

    var onPermissionsNeededTapped: (() -> Void)?

    init(coordinator: CaptureCoordinator) {
        self.coordinator = coordinator
    }

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "🎙"
        item.button?.toolTip = "speak — hold Right-Option to dictate"

        let menu = NSMenu()

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

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func pollState() async {
        var last: CaptureCoordinator.State = .idle
        while !Task.isCancelled {
            let current = await coordinator.state
            if current != last {
                last = current
                statusItem?.button?.title = title(for: current)
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
