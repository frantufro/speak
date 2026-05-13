import Foundation

public protocol HotkeyMonitor: AnyObject, Sendable {
    var onPress: (@Sendable () -> Void)? { get set }
    var onRelease: (@Sendable () -> Void)? { get set }
    func start()
    func stop()
}

public protocol AudioRecorder: AnyObject, Sendable {
    func start() async throws
    func stop() async -> AudioBuffer
}

public protocol STTEngine: AnyObject, Sendable {
    func transcribe(_ audio: AudioBuffer) async throws -> Transcription
}

public protocol PasteboardInjector: AnyObject, Sendable {
    func inject(_ text: String) async throws
}
