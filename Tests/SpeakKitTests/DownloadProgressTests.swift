import XCTest
import os
@testable import SpeakKit

// MARK: - Tests for download-blocking hotkey behaviour in CaptureCoordinator

final class DownloadProgressTests: XCTestCase {

    /// Pressing the hotkey while `isDownloading == true` must NOT start a capture
    /// and must invoke the download handler.
    func test_pressWhileDownloading_doesNotRecord_callsHandler() async throws {
        let hotkey = FakeHotkeyMonitor()
        let recorder = FakeAudioRecorder(audio: AudioBuffer(frames: [0.1]))
        let stt = FakeSTTEngine(result: Transcription(text: "hi", sourceLanguage: nil))
        let injector = SpyPasteboardInjector()

        let coordinator = CaptureCoordinator(
            hotkey: hotkey,
            recorder: recorder,
            stt: stt,
            injector: injector
        )
        await coordinator.start()

        // Set downloading flag and handler
        let handlerCalled = OSAllocatedUnfairLock(initialState: false)
        await coordinator.setDownloading(true)
        await coordinator.setHotkeyDuringDownloadHandler {
            handlerCalled.withLock { $0 = true }
        }

        // Press and release — should be blocked
        hotkey.simulatePress()
        hotkey.simulateRelease()

        // Give any potential async work a moment to run
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(recorder.startCount, 0, "Recording must not start while downloading")
        XCTAssertTrue(handlerCalled.withLock { $0 }, "Download handler must be called")
        let state = await coordinator.state
        XCTAssertEqual(state, .idle, "Coordinator must stay idle")
    }

    /// After the download finishes (`isDownloading = false`), hotkey press resumes normally.
    func test_pressAfterDownloadFinished_startsCapture() async throws {
        let hotkey = FakeHotkeyMonitor()
        let recorder = FakeAudioRecorder(audio: AudioBuffer(frames: [0.1, 0.2]))
        let stt = FakeSTTEngine(result: Transcription(text: "world", sourceLanguage: nil))
        let injector = SpyPasteboardInjector()

        let coordinator = CaptureCoordinator(
            hotkey: hotkey,
            recorder: recorder,
            stt: stt,
            injector: injector
        )
        await coordinator.start()

        // Simulate download then finish
        await coordinator.setDownloading(true)
        await coordinator.setDownloading(false)

        hotkey.simulatePress()
        await coordinator.waitForState(.recording)
        hotkey.simulateRelease()
        await coordinator.waitForState(.idle)

        XCTAssertEqual(recorder.startCount, 1, "Recording must start after download finishes")
        let injected = await injector.injectedTexts
        XCTAssertEqual(injected, ["world"])
    }

    /// Pressing the hotkey while `isDownloading == true` but with no handler set
    /// must still not start recording (no crash).
    func test_pressWhileDownloading_noHandlerSet_doesNotCrash() async throws {
        let hotkey = FakeHotkeyMonitor()
        let recorder = FakeAudioRecorder(audio: AudioBuffer(frames: [0.1]))
        let stt = FakeSTTEngine(result: Transcription(text: "hi", sourceLanguage: nil))
        let injector = SpyPasteboardInjector()

        let coordinator = CaptureCoordinator(
            hotkey: hotkey,
            recorder: recorder,
            stt: stt,
            injector: injector
        )
        await coordinator.start()
        await coordinator.setDownloading(true)

        hotkey.simulatePress()
        hotkey.simulateRelease()
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(recorder.startCount, 0, "Recording must not start while downloading")
    }
}
