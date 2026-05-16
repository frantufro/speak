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
    /// Override the Source language used during Transcription. Pass `nil` to re-enable auto-detect.
    func setLanguage(_ code: String?)

    /// Snapshot of whether this engine is ready to transcribe right now.
    /// Synchronous read; the engine is responsible for thread-safe state storage.
    var modelState: ModelState { get }

    /// Subscribe to ModelState transitions. Yields the current state immediately,
    /// then each subsequent transition.
    func modelStateUpdates() -> AsyncStream<ModelState>
}

public protocol PasteboardInjector: AnyObject, Sendable {
    func inject(_ text: String) async throws
}

/// An STT engine whose model must be downloaded before it can transcribe.
/// Conforms to `STTEngine` and adds commands that mutate download state.
public protocol DownloadableSTTEngine: STTEngine {
    /// Start downloading the model if it isn't cached yet.
    /// No-ops if already cached or already downloading.
    func ensureModelDownloaded() async

    /// Switch to a different model. Evicts the cached engine and starts a download
    /// if the model is not already cached.
    func switchModel(_ newModelName: String) async
}
