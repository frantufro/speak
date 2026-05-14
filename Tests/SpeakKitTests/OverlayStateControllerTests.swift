import XCTest
@testable import SpeakKit

final class OverlayStateControllerTests: XCTestCase {

    // MARK: - Helpers

    /// A sleep that resolves only when manually "ticked".
    private final class ManualClock: @unchecked Sendable {
        private var continuations: [CheckedContinuation<Void, Error>] = []
        private let lock = NSLock()

        func sleep(for _: Duration) async throws {
            try Task.checkCancellation()
            try await withCheckedThrowingContinuation { cont in
                lock.withLock { continuations.append(cont) }
            }
            try Task.checkCancellation()
        }

        /// Resolve all pending sleeps (i.e., fire the timers).
        func tick() {
            let waiting = lock.withLock { continuations.spliced() }
            for cont in waiting { cont.resume() }
        }

        /// Cancel all pending sleeps.
        func cancelAll() {
            let waiting = lock.withLock { continuations.spliced() }
            for cont in waiting { cont.resume(throwing: CancellationError()) }
        }
    }

    private func makeController(
        clock: ManualClock,
        commands: _CommandSpy
    ) -> OverlayStateController {
        OverlayStateController(
            autoHideDelay: .milliseconds(250),
            sleep: { [weak clock] d in try await clock?.sleep(for: d) ?? {} () },
            onCommand: { [weak commands] cmd in commands?.record(cmd) }
        )
    }

    // MARK: - Tests

    func test_recording_emitsShowRecording() {
        let clock = ManualClock()
        let spy = _CommandSpy()
        let ctrl = makeController(clock: clock, commands: spy)

        ctrl.handle(.recording)

        XCTAssertEqual(spy.commands, [.show(.recording)])
    }

    func test_transcribing_emitsShowTranscribing() {
        let clock = ManualClock()
        let spy = _CommandSpy()
        let ctrl = makeController(clock: clock, commands: spy)

        ctrl.handle(.transcribing)

        XCTAssertEqual(spy.commands, [.show(.transcribing)])
    }

    func test_idle_doesNotHideImmediately() {
        let clock = ManualClock()
        let spy = _CommandSpy()
        let ctrl = makeController(clock: clock, commands: spy)

        ctrl.handle(.idle)

        // No hide yet — timer hasn't fired.
        XCTAssertEqual(spy.commands, [])
    }

    func test_idle_hidesAfterTimerFires() async {
        let clock = ManualClock()
        let spy = _CommandSpy()
        let ctrl = makeController(clock: clock, commands: spy)

        ctrl.handle(.recording)
        ctrl.handle(.idle)

        // Give the task a moment to register with the clock, then tick.
        try? await Task.sleep(for: .milliseconds(10))
        clock.tick()
        try? await Task.sleep(for: .milliseconds(10))

        XCTAssertEqual(spy.commands, [.show(.recording), .hide])
    }

    func test_recordingAfterIdle_cancelsPendingHideAndEmitsShow() async {
        let clock = ManualClock()
        let spy = _CommandSpy()
        let ctrl = makeController(clock: clock, commands: spy)

        ctrl.handle(.recording)
        ctrl.handle(.idle)

        // New recording before timer fires — hide should be cancelled.
        ctrl.handle(.recording)

        // Tick the clock — should be a no-op since the timer was cancelled.
        try? await Task.sleep(for: .milliseconds(10))
        clock.tick()
        try? await Task.sleep(for: .milliseconds(10))

        // Only the two shows, no hide.
        XCTAssertEqual(spy.commands, [.show(.recording), .show(.recording)])
    }

    func test_injecting_schedulesHide() async {
        let clock = ManualClock()
        let spy = _CommandSpy()
        let ctrl = makeController(clock: clock, commands: spy)

        ctrl.handle(.recording)
        ctrl.handle(.injecting)

        try? await Task.sleep(for: .milliseconds(10))
        clock.tick()
        try? await Task.sleep(for: .milliseconds(10))

        XCTAssertEqual(spy.commands, [.show(.recording), .hide])
    }

    func test_transcribingToIdle_hidesAfterDelay() async {
        let clock = ManualClock()
        let spy = _CommandSpy()
        let ctrl = makeController(clock: clock, commands: spy)

        ctrl.handle(.transcribing)
        ctrl.handle(.idle)

        try? await Task.sleep(for: .milliseconds(10))
        clock.tick()
        try? await Task.sleep(for: .milliseconds(10))

        XCTAssertEqual(spy.commands, [.show(.transcribing), .hide])
    }
}

// MARK: - Helpers

final class _CommandSpy: @unchecked Sendable {
    private let lock = NSLock()
    private var _commands: [OverlayStateController.Command] = []

    var commands: [OverlayStateController.Command] { lock.withLock { _commands } }

    func record(_ cmd: OverlayStateController.Command) {
        lock.withLock { _commands.append(cmd) }
    }
}

private extension Array {
    /// Remove and return all elements.
    mutating func spliced() -> [Element] {
        let all = self
        self = []
        return all
    }
}
