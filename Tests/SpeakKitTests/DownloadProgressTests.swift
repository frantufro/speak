import XCTest
import os
@testable import SpeakKit

// MARK: - Tests for ModelState-based hotkey blocking in CaptureCoordinator

final class DownloadProgressTests: XCTestCase {

    /// Pressing the Hold-to-talk hotkey while modelState is .notReady must NOT start a Capture
    /// and must invoke the hotkeyWhileModelNotReady handler with the NotReadyReason.
    func test_pressWhileModelNotReady_doesNotRecord_callsHandler() async throws {
        let hotkey = FakeHotkeyMonitor()
        let recorder = FakeAudioRecorder(audio: AudioBuffer(frames: [0.1]))
        let stt = FakeSTTEngine(
            result: Transcription(text: "hi", sourceLanguage: nil),
            modelState: .notReady(.downloading(fraction: 0.5))
        )
        let injector = SpyPasteboardInjector()

        let coordinator = CaptureCoordinator(
            hotkey: hotkey,
            recorder: recorder,
            stt: stt,
            injector: injector
        )
        await coordinator.start()

        let handlerCalled = OSAllocatedUnfairLock(initialState: false)
        let capturedReason = OSAllocatedUnfairLock<NotReadyReason?>(initialState: nil)
        await coordinator.setHotkeyWhileModelNotReadyHandler { reason in
            handlerCalled.withLock { $0 = true }
            capturedReason.withLock { $0 = reason }
        }

        hotkey.simulatePress()
        hotkey.simulateRelease()

        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(recorder.startCount, 0, "Recording must not start while model is not ready")
        XCTAssertTrue(handlerCalled.withLock { $0 }, "Not-ready handler must be called")
        XCTAssertEqual(capturedReason.withLock { $0 }, .downloading(fraction: 0.5), "Handler must receive the NotReadyReason")
        let state = await coordinator.state
        XCTAssertEqual(state, .idle, "Coordinator must stay idle")
    }

    /// After the model becomes ready, hotkey press resumes normally.
    func test_pressAfterModelReady_startsCapture() async throws {
        let hotkey = FakeHotkeyMonitor()
        let recorder = FakeAudioRecorder(audio: AudioBuffer(frames: [0.1, 0.2]))
        let stt = FakeSTTEngine(
            result: Transcription(text: "world", sourceLanguage: nil),
            modelState: .ready
        )
        let injector = SpyPasteboardInjector()

        let coordinator = CaptureCoordinator(
            hotkey: hotkey,
            recorder: recorder,
            stt: stt,
            injector: injector
        )
        await coordinator.start()

        hotkey.simulatePress()
        await coordinator.waitForState(.recording)
        hotkey.simulateRelease()
        await coordinator.waitForState(.idle)

        XCTAssertEqual(recorder.startCount, 1, "Recording must start when model is ready")
        let injected = await injector.injectedTexts
        XCTAssertEqual(injected, ["world"])
    }

    /// Pressing the hotkey while model is not ready but with no handler set
    /// must still not start recording (no crash).
    func test_pressWhileModelNotReady_noHandlerSet_doesNotCrash() async throws {
        let hotkey = FakeHotkeyMonitor()
        let recorder = FakeAudioRecorder(audio: AudioBuffer(frames: [0.1]))
        let stt = FakeSTTEngine(
            result: Transcription(text: "hi", sourceLanguage: nil),
            modelState: .notReady(.checking)
        )
        let injector = SpyPasteboardInjector()

        let coordinator = CaptureCoordinator(
            hotkey: hotkey,
            recorder: recorder,
            stt: stt,
            injector: injector
        )
        await coordinator.start()

        hotkey.simulatePress()
        hotkey.simulateRelease()
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(recorder.startCount, 0, "Recording must not start while model is not ready")
    }

    /// Pressing the hotkey while modelState is .notReady(.failed) must call the handler
    /// with the failed reason and NOT start recording.
    func test_pressWhileModelFailed_callsHandlerWithFailedReason() async throws {
        let hotkey = FakeHotkeyMonitor()
        let recorder = FakeAudioRecorder(audio: AudioBuffer(frames: [0.1]))
        let stt = FakeSTTEngine(
            result: Transcription(text: "hi", sourceLanguage: nil),
            modelState: .notReady(.failed(message: "network error"))
        )
        let injector = SpyPasteboardInjector()

        let coordinator = CaptureCoordinator(
            hotkey: hotkey,
            recorder: recorder,
            stt: stt,
            injector: injector
        )
        await coordinator.start()

        let capturedReason = OSAllocatedUnfairLock<NotReadyReason?>(initialState: nil)
        await coordinator.setHotkeyWhileModelNotReadyHandler { reason in
            capturedReason.withLock { $0 = reason }
        }

        hotkey.simulatePress()
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(recorder.startCount, 0, "Recording must not start with failed model")
        XCTAssertEqual(capturedReason.withLock { $0 }, .failed(message: "network error"))
        let state = await coordinator.state
        XCTAssertEqual(state, .idle, "Coordinator must remain idle")
    }
}
