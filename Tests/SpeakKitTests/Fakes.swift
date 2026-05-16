import Foundation
@testable import SpeakKit

final class FakeHotkeyMonitor: HotkeyMonitor, @unchecked Sendable {
    var onPress: (@Sendable () -> Void)?
    var onRelease: (@Sendable () -> Void)?
    private(set) var currentCombo: HotkeyCombo = .rightOption

    func start() {}
    func stop() {}
    func rebind(_ newCombo: HotkeyCombo) { currentCombo = newCombo }

    func simulatePress() { onPress?() }
    func simulateRelease() { onRelease?() }
}

final class FakeAudioRecorder: AudioRecorder, @unchecked Sendable {
    private let audio: AudioBuffer
    private let lock = NSLock()
    private var _startCount = 0
    private var _stopCount = 0

    var startCount: Int { lock.withLock { _startCount } }
    var stopCount: Int { lock.withLock { _stopCount } }

    init(audio: AudioBuffer) { self.audio = audio }

    func start() async throws {
        lock.withLock { _startCount += 1 }
    }
    func stop() async -> AudioBuffer {
        lock.withLock { _stopCount += 1 }
        return audio
    }
}

final class HangingSTTEngine: STTEngine, @unchecked Sendable {
    private let result: Transcription
    private let stream: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation

    var modelState: ModelState = .ready

    init(result: Transcription) {
        var cont: AsyncStream<Void>.Continuation!
        self.stream = AsyncStream { cont = $0 }
        self.continuation = cont
        self.result = result
    }

    func transcribe(_ audio: AudioBuffer) async throws -> Transcription {
        var iterator = stream.makeAsyncIterator()
        _ = await iterator.next()
        return result
    }

    func setLanguage(_ code: String?) {}

    func modelStateUpdates() -> AsyncStream<ModelState> {
        let current = modelState
        return AsyncStream { cont in
            cont.yield(current)
            cont.finish()
        }
    }

    func releaseTranscription() {
        continuation.yield()
    }
}

final class FakeSTTEngine: STTEngine, @unchecked Sendable {
    enum Outcome {
        case success(Transcription)
        case failure(Error)
    }
    private let outcome: Outcome
    var modelState: ModelState

    init(result: Transcription, modelState: ModelState = .ready) {
        self.outcome = .success(result)
        self.modelState = modelState
    }
    init(error: Error) {
        self.outcome = .failure(error)
        self.modelState = .ready
    }

    func transcribe(_ audio: AudioBuffer) async throws -> Transcription {
        switch outcome {
        case .success(let t): return t
        case .failure(let e): throw e
        }
    }

    func setLanguage(_ code: String?) {}

    func modelStateUpdates() -> AsyncStream<ModelState> {
        let current = modelState
        return AsyncStream { cont in
            cont.yield(current)
            cont.finish()
        }
    }
}

actor SpyPasteboardInjector: PasteboardInjector {
    private(set) var injectedTexts: [String] = []

    func inject(_ text: String) async throws {
        injectedTexts.append(text)
    }
}

actor FailingPasteboardInjector: PasteboardInjector {
    private(set) var attemptCount = 0
    private let error: Error

    init(error: Error) { self.error = error }

    func inject(_ text: String) async throws {
        attemptCount += 1
        throw error
    }
}
