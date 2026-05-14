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

/// An STT engine that can also report model-download progress.
/// Conforms to `STTEngine` and adds a progress stream and a download trigger.
public protocol DownloadableSTTEngine: STTEngine {
    /// Returns an `AsyncStream` that emits `DownloadProgress` events while a
    /// model is being downloaded. Completes immediately when no download is active.
    func downloadProgressStream() -> AsyncStream<DownloadProgress>

    /// Start downloading the model if it isn't cached yet.
    /// No-ops if already cached or already downloading.
    func ensureModelDownloaded() async
}
