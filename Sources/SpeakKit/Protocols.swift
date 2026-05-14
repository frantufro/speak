import Foundation

public protocol HotkeyMonitor: AnyObject, Sendable {
    var onPress: (@Sendable () -> Void)? { get set }
    var onRelease: (@Sendable () -> Void)? { get set }
    func start()
    func stop()
    /// Tear down and re-install the event tap for the given combo.
    /// Safe to call at any time; if a capture is in-flight the rebind is deferred until the tap
    /// is next re-enabled, so no events are lost.
    func rebind(_ newCombo: HotkeyCombo)
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
