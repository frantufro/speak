import Foundation

public actor CaptureCoordinator {
    public enum State: Sendable, Equatable {
        case idle
        case recording
        case transcribing
        case injecting
    }

    public private(set) var state: State = .idle

    private let hotkey: HotkeyMonitor
    private let recorder: AudioRecorder
    private let stt: STTEngine
    private let injector: PasteboardInjector
    private let maxCaptureDuration: Duration

    /// Called (on the actor) when the user presses the hotkey while a model download
    /// is in progress. The coordinator will NOT start recording in this case.
    private var onHotkeyPressedDuringDownload: (@Sendable () -> Void)?

    /// When true, hotkey presses are blocked and trigger `onHotkeyPressedDuringDownload`.
    public private(set) var isDownloading: Bool = false

    /// Set the callback to invoke when the hotkey is pressed during a download.
    public func setHotkeyDuringDownloadHandler(_ handler: @escaping @Sendable () -> Void) {
        onHotkeyPressedDuringDownload = handler
    }

    private var stateWaiters: [(State, CheckedContinuation<Void, Never>)] = []
    private var capTimerTask: Task<Void, Never>?
    private var streamContinuations: [UUID: AsyncStream<State>.Continuation] = [:]

    /// Yields each state transition as it happens. The first element is the
    /// *current* state so that a new observer can synchronise immediately.
    public func stateStream() -> AsyncStream<State> {
        let id = UUID()
        let current = state
        return AsyncStream<State> { [weak self] continuation in
            continuation.yield(current)
            Task { [weak self] in
                await self?.addContinuation(continuation, id: id)
            }
            continuation.onTermination = { [weak self] _ in
                Task { [weak self] in
                    await self?.removeContinuation(id: id)
                }
            }
        }
    }

    private func addContinuation(_ continuation: AsyncStream<State>.Continuation, id: UUID) {
        streamContinuations[id] = continuation
    }

    private func removeContinuation(id: UUID) {
        streamContinuations.removeValue(forKey: id)
    }

    public init(
        hotkey: HotkeyMonitor,
        recorder: AudioRecorder,
        stt: STTEngine,
        injector: PasteboardInjector,
        maxCaptureDuration: Duration = .seconds(180)
    ) {
        self.hotkey = hotkey
        self.recorder = recorder
        self.stt = stt
        self.injector = injector
        self.maxCaptureDuration = maxCaptureDuration
    }

    public func start() {
        hotkey.onPress = { [weak self] in
            Task { await self?.handlePress() }
        }
        hotkey.onRelease = { [weak self] in
            Task { await self?.handleRelease() }
        }
        hotkey.start()
    }

    public func waitForState(_ target: State) async {
        if state == target { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            stateWaiters.append((target, continuation))
        }
    }

    private func setState(_ new: State) {
        let previous = state
        state = new
        if previous != new {
            Diagnostics.log("state \(previous) → \(new)")
            for continuation in streamContinuations.values {
                continuation.yield(new)
            }
        }
        let (matching, remaining) = stateWaiters.partitioned { $0.0 == new }
        stateWaiters = remaining
        for waiter in matching {
            waiter.1.resume()
        }
    }

    /// Update the downloading flag. Call from AppDelegate/download observer on main actor.
    public func setDownloading(_ downloading: Bool) {
        isDownloading = downloading
        Diagnostics.log("coordinator: isDownloading=\(downloading)")
    }

    private func handlePress() async {
        Diagnostics.log("hotkey press (state=\(state), isDownloading=\(isDownloading))")
        if isDownloading {
            onHotkeyPressedDuringDownload?()
            return
        }
        guard state == .idle else { return }
        setState(.recording)
        let cap = maxCaptureDuration
        capTimerTask = Task { [weak self] in
            // `try? await Task.sleep` swallows CancellationError, so we must
            // check `Task.isCancelled` explicitly — otherwise a release that
            // races with sleep cancellation would still fire the cap handler.
            try? await Task.sleep(for: cap)
            if Task.isCancelled { return }
            await self?.forceReleaseFromCap()
        }
        do {
            try await recorder.start()
        } catch {
            Diagnostics.log("recorder.start failed: \(error)")
            capTimerTask?.cancel()
            capTimerTask = nil
            setState(.idle)
        }
    }

    private func handleRelease() async {
        Diagnostics.log("hotkey release (state=\(state))")
        guard state == .recording else { return }
        capTimerTask?.cancel()
        capTimerTask = nil
        await processRelease()
    }

    private func forceReleaseFromCap() async {
        Diagnostics.log("3-min cap fired (state=\(state))")
        guard state == .recording else { return }
        capTimerTask = nil
        await processRelease()
    }

    private func processRelease() async {
        let audio = await recorder.stop()
        Diagnostics.log("recorder.stop returned \(audio.frames.count) frames")
        guard !audio.isEmpty else {
            Diagnostics.log("empty capture — returning to idle")
            setState(.idle)
            return
        }
        setState(.transcribing)
        do {
            let transcription = try await stt.transcribe(audio)
            let trimmed = transcription.text.trimmingCharacters(in: .whitespacesAndNewlines)
            Diagnostics.log("transcribed \(trimmed.count) chars: \"\(trimmed.prefix(60))\"")
            if !trimmed.isEmpty {
                setState(.injecting)
                try await injector.inject(transcription.text)
            }
        } catch {
            Diagnostics.log("transcribe or inject failed: \(error)")
        }
        setState(.idle)
    }
}

private extension Array {
    func partitioned(by belongsInFirst: (Element) -> Bool) -> ([Element], [Element]) {
        var first: [Element] = []
        var second: [Element] = []
        for element in self {
            if belongsInFirst(element) {
                first.append(element)
            } else {
                second.append(element)
            }
        }
        return (first, second)
    }
}
