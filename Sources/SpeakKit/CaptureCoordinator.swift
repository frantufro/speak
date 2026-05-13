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

    private var stateWaiters: [(State, CheckedContinuation<Void, Never>)] = []
    private var capTimerTask: Task<Void, Never>?

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
        }
        let (matching, remaining) = stateWaiters.partitioned { $0.0 == new }
        stateWaiters = remaining
        for waiter in matching {
            waiter.1.resume()
        }
    }

    private func handlePress() async {
        Diagnostics.log("hotkey press (state=\(state))")
        guard state == .idle else { return }
        setState(.recording)
        let cap = maxCaptureDuration
        capTimerTask = Task { [weak self] in
            try? await Task.sleep(for: cap)
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
