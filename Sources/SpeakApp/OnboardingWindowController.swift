import AppKit
import SpeakKit

/// Walks the user through granting the three permissions speak needs.
/// Present modally by calling `show(startingAt:)`.
@MainActor
final class OnboardingWindowController: NSWindowController {
    private let permissionsService: PermissionsService
    private var currentStep: PermissionKind
    private var contentView: OnboardingView!
    private var didBecomeActiveObserver: NSObjectProtocol?

    var onDone: (() -> Void)?

    init(permissionsService: PermissionsService, startingAt step: PermissionKind = .microphone) {
        self.permissionsService = permissionsService
        self.currentStep = step

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "speak — permissions"
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)

        contentView = OnboardingView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        window.contentView = contentView
        contentView.onGrant = { [weak self] in self?.handleGrant() }
        contentView.onSkip = { [weak self] in self?.advance() }
        updateView()

        // When the user returns from System Settings, re-check the status so
        // the wizard advances without requiring a menu-bar re-entry.
        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.handleAppDidBecomeActive() }
        }
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func show(startingAt step: PermissionKind? = nil) {
        if let step { currentStep = step }
        permissionsService.refresh()
        updateView()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Called by the AppDelegate when the periodic refresh notices a status
    /// change. Auto-advances if the current step is now granted.
    func permissionsStatusChanged(_ status: PermissionsStatus) {
        guard window?.isVisible == true else { return }
        if stateFor(currentStep, in: status) == .granted {
            advance()
        }
    }

    // MARK: - Private

    private static let steps: [PermissionKind] = [.microphone, .accessibility, .inputMonitoring]

    private func updateView() {
        let status = permissionsService.current()
        let stepIndex = Self.steps.firstIndex(of: currentStep) ?? 0
        contentView.update(
            stepIndex: stepIndex,
            totalSteps: Self.steps.count,
            kind: currentStep,
            alreadyGranted: stateFor(currentStep, in: status) == .granted
        )
    }

    private func stateFor(_ kind: PermissionKind, in status: PermissionsStatus) -> PermissionState {
        switch kind {
        case .microphone: return status.microphone
        case .accessibility: return status.accessibility
        case .inputMonitoring: return status.inputMonitoring
        }
    }

    private func handleGrant() {
        // If we've already got it (e.g. user toggled the permission while the
        // wizard was open and the periodic refresh hasn't fired yet), skip
        // straight to the next step.
        permissionsService.refresh()
        if stateFor(currentStep, in: permissionsService.current()) == .granted {
            advance()
            return
        }

        let step = currentStep
        permissionsService.request(step) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.permissionsService.refresh()
                let fresh = self.permissionsService.current()
                if self.stateFor(step, in: fresh) == .granted {
                    self.advance()
                } else {
                    // Most likely a System Settings flow (accessibility /
                    // input monitoring): the request returned before the user
                    // toggled the switch. Keep the wizard up; `didBecomeActive`
                    // will pick up the change when they come back.
                    self.window?.makeKeyAndOrderFront(nil)
                }
            }
        }
    }

    private func handleAppDidBecomeActive() {
        permissionsService.refresh()
        let status = permissionsService.current()
        if stateFor(currentStep, in: status) == .granted {
            advance()
        } else if window?.isVisible == true {
            window?.makeKeyAndOrderFront(nil)
        }
    }

    private func advance() {
        permissionsService.refresh()
        let steps = Self.steps
        guard let idx = steps.firstIndex(of: currentStep), idx + 1 < steps.count else {
            // All steps done
            close()
            onDone?()
            return
        }
        currentStep = steps[idx + 1]
        updateView()
        window?.makeKeyAndOrderFront(nil)
    }
}

// MARK: - View

private final class OnboardingView: NSView {
    var onGrant: (() -> Void)?
    var onSkip: (() -> Void)?

    private let stepLabel = NSTextField(labelWithString: "")
    private let titleLabel = NSTextField(labelWithString: "")
    private let bodyLabel = NSTextField(wrappingLabelWithString: "")
    private let grantButton = NSButton(title: "Grant access", target: nil, action: nil)
    private let skipButton = NSButton(title: "Skip for now", target: nil, action: nil)

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupSubviews()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private func setupSubviews() {
        stepLabel.font = .systemFont(ofSize: 11)
        stepLabel.textColor = .secondaryLabelColor

        titleLabel.font = .boldSystemFont(ofSize: 16)

        bodyLabel.font = .systemFont(ofSize: 13)
        bodyLabel.textColor = .secondaryLabelColor

        grantButton.bezelStyle = .rounded
        grantButton.keyEquivalent = "\r"
        grantButton.target = self
        grantButton.action = #selector(grantTapped)

        skipButton.bezelStyle = .rounded
        skipButton.target = self
        skipButton.action = #selector(skipTapped)

        for view in [stepLabel, titleLabel, bodyLabel, grantButton, skipButton] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }

        NSLayoutConstraint.activate([
            stepLabel.topAnchor.constraint(equalTo: topAnchor, constant: 24),
            stepLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),

            titleLabel.topAnchor.constraint(equalTo: stepLabel.bottomAnchor, constant: 6),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),

            bodyLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            bodyLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            bodyLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),

            skipButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
            skipButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),

            grantButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
            grantButton.trailingAnchor.constraint(equalTo: skipButton.leadingAnchor, constant: -8),
        ])
    }

    func update(stepIndex: Int, totalSteps: Int, kind: PermissionKind, alreadyGranted: Bool) {
        stepLabel.stringValue = "Step \(stepIndex + 1) of \(totalSteps)"
        let (title, body) = copy(for: kind)
        titleLabel.stringValue = title
        bodyLabel.stringValue = body

        if alreadyGranted {
            grantButton.title = "Continue"
            skipButton.isHidden = true
        } else {
            grantButton.title = actionTitle(for: kind)
            skipButton.isHidden = false
        }
    }

    @objc private func grantTapped() { onGrant?() }
    @objc private func skipTapped() { onSkip?() }

    // MARK: - Copy

    private func copy(for kind: PermissionKind) -> (title: String, body: String) {
        switch kind {
        case .microphone:
            return (
                "Microphone",
                "speak needs to hear you while you hold Right-Option. Audio is processed on your Mac — nothing leaves the device."
            )
        case .accessibility:
            return (
                "Accessibility",
                "speak needs Accessibility access to watch for the Right-Option key so it can start and stop recording without appearing in every app."
            )
        case .inputMonitoring:
            return (
                "Input Monitoring",
                "speak needs Input Monitoring so it can detect the Right-Option keypress system-wide, even when another app is in front."
            )
        }
    }

    private func actionTitle(for kind: PermissionKind) -> String {
        switch kind {
        case .microphone: return "Allow microphone"
        case .accessibility: return "Open System Settings"
        case .inputMonitoring: return "Allow input monitoring"
        }
    }
}
