import XCTest
@testable import SpeakKit

final class CaptureCoordinatorTests: XCTestCase {
    func test_happyPath_pressAndReleaseInjectsTranscription() async throws {
        let hotkey = FakeHotkeyMonitor()
        let recorder = FakeAudioRecorder(audio: AudioBuffer(frames: [0.1, 0.2, 0.3]))
        let stt = FakeSTTEngine(result: Transcription(text: "hello", sourceLanguage: .english))
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

        let injected = await injector.injectedTexts
        XCTAssertEqual(injected, ["hello"])
    }

    func test_overlap_pressDuringInflightCaptureIsIgnored() async throws {
        let hotkey = FakeHotkeyMonitor()
        let recorder = FakeAudioRecorder(audio: AudioBuffer(frames: [0.1]))
        let stt = HangingSTTEngine(result: Transcription(text: "first", sourceLanguage: nil))
        let injector = SpyPasteboardInjector()

        let coordinator = CaptureCoordinator(
            hotkey: hotkey, recorder: recorder, stt: stt, injector: injector
        )
        await coordinator.start()

        hotkey.simulatePress()
        await coordinator.waitForState(.recording)
        hotkey.simulateRelease()
        await coordinator.waitForState(.transcribing)

        // STT is hanging; press again. The press must be ignored.
        hotkey.simulatePress()
        // A second release would also be ignored, but include it for realism.
        hotkey.simulateRelease()

        stt.releaseTranscription()
        await coordinator.waitForState(.idle)

        XCTAssertEqual(recorder.startCount, 1, "Second press during transcribing must not start recording again")
        let injected = await injector.injectedTexts
        XCTAssertEqual(injected, ["first"], "Only the first Capture should have injected")
    }

    func test_emptyCapture_doesNotInject() async throws {
        let hotkey = FakeHotkeyMonitor()
        let recorder = FakeAudioRecorder(audio: AudioBuffer(frames: []))
        let stt = FakeSTTEngine(result: Transcription(text: "should not be injected", sourceLanguage: nil))
        let injector = SpyPasteboardInjector()

        let coordinator = CaptureCoordinator(
            hotkey: hotkey, recorder: recorder, stt: stt, injector: injector
        )
        await coordinator.start()

        hotkey.simulatePress()
        await coordinator.waitForState(.recording)
        hotkey.simulateRelease()
        await coordinator.waitForState(.idle)

        let injected = await injector.injectedTexts
        XCTAssertTrue(injected.isEmpty, "Empty Capture must not touch the pasteboard")
    }

    func test_sttFailure_returnsToIdleWithoutInjecting() async throws {
        enum FakeSTTError: Error { case boom }
        let hotkey = FakeHotkeyMonitor()
        let recorder = FakeAudioRecorder(audio: AudioBuffer(frames: [0.1]))
        let stt = FakeSTTEngine(error: FakeSTTError.boom)
        let injector = SpyPasteboardInjector()

        let coordinator = CaptureCoordinator(
            hotkey: hotkey, recorder: recorder, stt: stt, injector: injector
        )
        await coordinator.start()

        hotkey.simulatePress()
        await coordinator.waitForState(.recording)
        hotkey.simulateRelease()
        await coordinator.waitForState(.idle)

        let injected = await injector.injectedTexts
        XCTAssertTrue(injected.isEmpty, "STT failure must not cause an injection")
    }

    func test_captureCap_forcesReleaseAndTranscribesWhatWasCaptured() async throws {
        let hotkey = FakeHotkeyMonitor()
        let recorder = FakeAudioRecorder(audio: AudioBuffer(frames: [0.1, 0.2]))
        let stt = FakeSTTEngine(result: Transcription(text: "cut off", sourceLanguage: nil))
        let injector = SpyPasteboardInjector()

        let coordinator = CaptureCoordinator(
            hotkey: hotkey, recorder: recorder, stt: stt, injector: injector,
            maxCaptureDuration: .milliseconds(50)
        )
        await coordinator.start()

        hotkey.simulatePress()
        await coordinator.waitForState(.recording)
        // Do not release. The cap must force-release on its own.
        await coordinator.waitForState(.idle)

        XCTAssertEqual(recorder.stopCount, 1, "Cap must stop the recorder")
        let injected = await injector.injectedTexts
        XCTAssertEqual(injected, ["cut off"], "Captured audio up to the cap must still be transcribed")
    }

    func test_injectionFailure_returnsToIdleCleanly() async throws {
        enum InjectionError: Error { case secureInput }
        let hotkey = FakeHotkeyMonitor()
        let recorder = FakeAudioRecorder(audio: AudioBuffer(frames: [0.1]))
        let stt = FakeSTTEngine(result: Transcription(text: "blocked", sourceLanguage: nil))
        let injector = FailingPasteboardInjector(error: InjectionError.secureInput)

        let coordinator = CaptureCoordinator(
            hotkey: hotkey, recorder: recorder, stt: stt, injector: injector
        )
        await coordinator.start()

        hotkey.simulatePress()
        await coordinator.waitForState(.recording)
        hotkey.simulateRelease()
        await coordinator.waitForState(.idle)

        let attempts = await injector.attemptCount
        XCTAssertEqual(attempts, 1, "Coordinator must still attempt injection; refusal happens inside the injector")
    }
}
