import AppKit

/// Displays a short transient floating bezel in the bottom-right of the
/// active screen. Not a Notification Center notification.
///
/// `ToastPresenter.show(_:)` is safe to call from any thread; it dispatches
/// to the main thread internally.
@MainActor
public final class ToastPresenter {
    public static let shared = ToastPresenter()

    private var currentWindow: ToastWindow?

    private init() {}

    /// Show a toast with `text`. Auto-dismisses after `duration` seconds.
    /// Replaces any currently-visible toast.
    public func show(_ text: String, duration: TimeInterval = 3.0) {
        currentWindow?.close()
        let window = ToastWindow(text: text)
        currentWindow = window
        window.show()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            if currentWindow === window {
                window.close()
                currentWindow = nil
            }
        }
    }
}

// MARK: - Window

@MainActor
final class ToastWindow: NSWindow {
    init(text: String) {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        isReleasedWhenClosed = false
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        ignoresMouseEvents = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        label.maximumNumberOfLines = 2
        label.lineBreakMode = .byWordWrapping
        label.preferredMaxLayoutWidth = 280

        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.80).cgColor
        container.layer?.cornerRadius = 10

        container.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
        ])

        contentView = container

        // Size to fit
        label.sizeToFit()
        let labelSize = label.fittingSize
        let width = min(labelSize.width + 28, 308)
        let height = labelSize.height + 20
        setContentSize(NSSize(width: width, height: height))

        // Position: bottom-right of active screen, 20 pt margin
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let visibleRect = screen.visibleFrame
        let origin = NSPoint(
            x: visibleRect.maxX - frame.width - 20,
            y: visibleRect.minY + 20
        )
        setFrameOrigin(origin)

        // Dismiss on click
        let click = NSClickGestureRecognizer(target: self, action: #selector(dismiss))
        container.addGestureRecognizer(click)
    }

    func show() {
        alphaValue = 0
        makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            animator().alphaValue = 1
        }
    }

    override func close() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            self.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            // completionHandler is always called on the main thread by AppKit,
            // but the compiler can't verify that; use MainActor.assumeIsolated.
            MainActor.assumeIsolated { self?.orderOut(nil) }
        })
    }

    @objc private func dismiss() {
        close()
    }
}
