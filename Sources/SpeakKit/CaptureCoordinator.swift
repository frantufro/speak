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
        state = new
        let (matching, remaining) = stateWaiters.partitioned { $0.0 == new }
        stateWaiters = remaining
        for waiter in matching {
            waiter.1.resume()
        }
    }

    private func handlePress() async {
        guard state == .idle else { return }
        setState(.recording)
        let cap = maxCaptureDuration
        capTimerTask = Task { [weak self] in
            try? await Task.sleep(for: cap)
            await self?.forceReleaseFromCap()
        }
        try? await recorder.start()
    }

    private func handleRelease() async {
        guard state == .recording else { return }
        capTimerTask?.cancel()
        capTimerTask = nil
        await processRelease()
    }

    private func forceReleaseFromCap() async {
        guard state == .recording else { return }
        capTimerTask = nil
        await processRelease()
    }

    private func processRelease() async {
        let audio = await recorder.stop()
        guard !audio.isEmpty else {
            setState(.idle)
            return
        }
        setState(.transcribing)
        do {
            let transcription = try await stt.transcribe(audio)
            let trimmed = transcription.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                setState(.injecting)
                try await injector.inject(transcription.text)
            }
        } catch {
            // STT or injection failed; return to idle silently for now.
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
