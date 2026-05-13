@preconcurrency import AVFoundation
import os
import SpeakKit

public final class AVAudioEngineRecorder: SpeakKit.AudioRecorder, @unchecked Sendable {
    public enum RecorderError: Error {
        case microphonePermissionDenied
        case converterUnavailable
        case engineFailedToStart(underlying: Error)
    }

    private struct State {
        var buffer: [Float] = []
        var isRunning = false
    }

    private let engine = AVAudioEngine()
    private let state = OSAllocatedUnfairLock<State>(initialState: State())
    private var converter: AVAudioConverter?
    private var targetFormat: AVAudioFormat?

    public init() {}

    public func start() async throws {
        try await requestMicrophoneAccessIfNeeded()

        let alreadyRunning = state.withLock { current -> Bool in
            if current.isRunning { return true }
            current.buffer.removeAll(keepingCapacity: true)
            return false
        }
        guard !alreadyRunning else { return }

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        Diagnostics.log("audio input format: \(inputFormat)")
        guard let target = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        ) else {
            throw RecorderError.converterUnavailable
        }
        guard let converter = AVAudioConverter(from: inputFormat, to: target) else {
            throw RecorderError.converterUnavailable
        }
        self.converter = converter
        self.targetFormat = target

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 4_096, format: inputFormat) { [weak self] pcm, _ in
            self?.appendConvertedFrames(from: pcm)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw RecorderError.engineFailedToStart(underlying: error)
        }
        state.withLock { $0.isRunning = true }
        Diagnostics.log("audio engine started")
    }

    public func stop() async -> SpeakKit.AudioBuffer {
        let wasRunning = state.withLock { current -> Bool in
            let running = current.isRunning
            current.isRunning = false
            return running
        }

        if wasRunning {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }

        let frames = state.withLock { current -> [Float] in
            let result = current.buffer
            current.buffer.removeAll(keepingCapacity: false)
            return result
        }
        return SpeakKit.AudioBuffer(frames: frames)
    }

    private func appendConvertedFrames(from input: AVAudioPCMBuffer) {
        guard let converter, let targetFormat else { return }
        let ratio = targetFormat.sampleRate / input.format.sampleRate
        let capacity = AVAudioFrameCount(Double(input.frameLength) * ratio) + 1_024
        guard let output = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }

        let pendingInput = UnsafeMutablePointer<AVAudioPCMBuffer?>.allocate(capacity: 1)
        pendingInput.initialize(to: input)
        defer {
            pendingInput.deinitialize(count: 1)
            pendingInput.deallocate()
        }

        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, inputStatus in
            if let pending = pendingInput.pointee {
                pendingInput.pointee = nil
                inputStatus.pointee = .haveData
                return pending
            }
            inputStatus.pointee = .noDataNow
            return nil
        }
        guard status != .error, let channel = output.floatChannelData?.pointee else { return }
        let count = Int(output.frameLength)
        let frames = Array(UnsafeBufferPointer(start: channel, count: count))

        state.withLock { $0.buffer.append(contentsOf: frames) }
    }

    private func requestMicrophoneAccessIfNeeded() async throws {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        Diagnostics.log("mic authorization status: \(status.rawValue)")
        switch status {
        case .authorized:
            return
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            Diagnostics.log("mic permission prompt result: \(granted)")
            if !granted { throw RecorderError.microphonePermissionDenied }
        case .denied, .restricted:
            throw RecorderError.microphonePermissionDenied
        @unknown default:
            throw RecorderError.microphonePermissionDenied
        }
    }
}
