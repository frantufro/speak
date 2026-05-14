import AppKit
import SpeakKit

/// Owns the floating ``OverlayWindow`` and drives it from ``CaptureCoordinator``
/// state changes observed via ``CaptureCoordinator/stateStream()``.
///
/// All window manipulation runs on the main actor.
@MainActor
public final class OverlayPresenter {
    private let coordinator: CaptureCoordinator
    private let window = OverlayWindow()
    private var observeTask: Task<Void, Never>?
    private var downloadTask: Task<Void, Never>?
    private var isShowingDownload = false

    public init(coordinator: CaptureCoordinator) {
        self.coordinator = coordinator
    }

    public func start() {
        let coordinator = self.coordinator

        // Build a state controller whose command handler runs on the main actor.
        let ctrl = OverlayStateController { [weak self] command in
            // Hop to main actor for all window operations.
            Task { @MainActor [weak self] in
                guard let self else { return }
                // Don't let capture-state commands hide the overlay during a download.
                if self.isShowingDownload, case .hide = command { return }
                self.apply(command)
            }
        }

        observeTask = Task { [weak self, ctrl] in
            let stream = await coordinator.stateStream()
            for await state in stream {
                guard self != nil else { break }
                Diagnostics.log("overlay: coordinator state → \(state)")
                ctrl.handle(state)
            }
        }
    }

    /// Start showing download progress in the overlay.
    public func observeDownloadProgress(_ stream: AsyncStream<SpeakKit.DownloadProgress>) {
        downloadTask?.cancel()
        downloadTask = Task { [weak self] in
            for await event in stream {
                guard let self else { break }
                switch event {
                case .downloading(let fraction):
                    self.isShowingDownload = true
                    let percent = Int(fraction * 100)
                    self.positionWindowNearCursor()
                    self.window.updateDownloadProgress(percent: percent)
                    self.window.orderFrontRegardless()
                case .completed, .failed:
                    self.isShowingDownload = false
                    self.window.orderOut(nil)
                }
            }
            self?.isShowingDownload = false
        }
    }

    public func stop() {
        observeTask?.cancel()
        observeTask = nil
        downloadTask?.cancel()
        downloadTask = nil
        window.orderOut(nil)
    }

    // MARK: - Private

    private func apply(_ command: OverlayStateController.Command) {
        switch command {
        case .show(let state):
            positionWindowNearCursor()
            window.update(state: state)
            window.orderFrontRegardless()
        case .hide:
            window.orderOut(nil)
        }
    }

    /// Positions the overlay near the current cursor, offset upward so it sits
    /// just above the cursor rather than on top of it.
    private func positionWindowNearCursor() {
        let mouse = NSEvent.mouseLocation  // Flipped (bottom-left origin) coords
        let windowSize = window.frame.size

        // Find the screen the cursor is on.
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens.first

        guard let screen else {
            Diagnostics.log("overlay: no screen found — keeping current position")
            return
        }

        var origin: NSPoint
        if screen.frame.contains(mouse) {
            // Place the pill just above and horizontally centred on the cursor.
            let offsetY: CGFloat = 24
            origin = NSPoint(
                x: mouse.x - windowSize.width / 2,
                y: mouse.y + offsetY
            )
        } else {
            // Fallback: top-centre of the active screen.
            origin = NSPoint(
                x: screen.visibleFrame.midX - windowSize.width / 2,
                y: screen.visibleFrame.maxY - windowSize.height - 8
            )
            Diagnostics.log("overlay: cursor not on any screen — using top-center fallback")
        }

        // Clamp to screen bounds so the pill never hangs off an edge.
        let sf = screen.visibleFrame
        origin.x = max(sf.minX, min(origin.x, sf.maxX - windowSize.width))
        origin.y = max(sf.minY, min(origin.y, sf.maxY - windowSize.height))

        window.setFrameOrigin(origin)
    }
}
