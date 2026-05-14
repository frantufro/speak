import Foundation

/// Pure (AppKit-free) logic that maps ``CaptureCoordinator/State`` transitions
/// to overlay visibility commands.
///
/// Rules:
/// - `recording` or `transcribing` → show the overlay immediately.
/// - `idle` (or `injecting`) after a visible state → schedule an auto-hide
///   after `autoHideDelay`; cancel the timer if a new non-idle state arrives.
public final class OverlayStateController: Sendable {
    public enum Command: Sendable, Equatable {
        case show(CaptureCoordinator.State)
        case hide
    }

    public let autoHideDelay: Duration
    private let _onCommand: @Sendable (Command) -> Void
    private let _sleep: @Sendable (Duration) async throws -> Void

    // Shared mutable state, protected by actor isolation via Task ordering.
    private let _hideTask: _Box<Task<Void, Never>?> = .init(nil)

    public init(
        autoHideDelay: Duration = .milliseconds(250),
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        onCommand: @escaping @Sendable (Command) -> Void
    ) {
        self.autoHideDelay = autoHideDelay
        self._sleep = sleep
        self._onCommand = onCommand
    }

    /// Feed a new coordinator state in. Safe to call from any concurrency context.
    public func handle(_ state: CaptureCoordinator.State) {
        switch state {
        case .recording, .transcribing:
            _hideTask.value?.cancel()
            _hideTask.value = nil
            _onCommand(.show(state))
        case .idle, .injecting:
            _hideTask.value?.cancel()
            let delay = autoHideDelay
            let sleep = _sleep
            let onCommand = _onCommand
            let box = _hideTask
            box.value = Task {
                do {
                    try await sleep(delay)
                    onCommand(.hide)
                    box.value = nil
                } catch {
                    // Task cancelled — a new visible state arrived; do nothing.
                }
            }
        }
    }
}

/// Non-sendable mutable box used only as actor-local storage inside the module.
private final class _Box<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}
