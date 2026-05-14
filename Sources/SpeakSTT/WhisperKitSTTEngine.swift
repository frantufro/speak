import Foundation
import SpeakKit
@preconcurrency import WhisperKit
import os

/// Adapter over WhisperKit. The engine is loaded lazily on the first transcription
/// so the menu-bar shell starts instantly; first-press latency is dominated by load+specialize.
///
/// WhisperKit itself is not `Sendable`, so this wrapper is marked `@unchecked Sendable`.
public final class WhisperKitSTTEngine: SpeakKit.STTEngine, SpeakKit.DownloadableSTTEngine, @unchecked Sendable {

    private let stateLock = OSAllocatedUnfairLock(initialState: State())

    public init(modelName: String = "openai_whisper-large-v3-v20240930_turbo") {
        stateLock.withLock { $0.modelName = modelName }
    }

    // MARK: - Public API

    /// Override the source language WhisperKit uses. Pass `nil` to re-enable auto-detect.
    public func setLanguage(_ code: String?) {
        stateLock.withLock { $0.forcedLanguage = code }
    }

    /// Switch to a different model. If `newModelName` differs and isn't cached,
    /// evicts the cached engine and starts a fresh download.
    public func switchModel(_ newModelName: String) async {
        let needsSwitch = stateLock.withLock { state -> Bool in
            guard newModelName != state.modelName else { return false }
            state.modelName = newModelName
            state.cachedEngine = nil
            state.isDownloading = false
            return true
        }
        guard needsSwitch else { return }
        Diagnostics.log("whisperkit: switched model to \(newModelName)")
        await ensureModelDownloaded()
    }

    // MARK: - DownloadableSTTEngine

    /// Returns a stream of download progress events for the *current or next* download.
    /// The stream receives events if a download starts (or is already running).
    /// The caller should call this before `ensureModelDownloaded()` to avoid missing events.
    public func downloadProgressStream() -> AsyncStream<SpeakKit.DownloadProgress> {
        let (stream, cont) = AsyncStream<SpeakKit.DownloadProgress>.makeStream()
        stateLock.withLock { state in
            if state.cachedEngine != nil {
                // Model already loaded; no download will happen.
                cont.finish()
            } else {
                // Register for upcoming (or current) download events.
                state.continuations.append(cont)
            }
        }
        return stream
    }

    /// Begin downloading/loading the model if not already cached or downloading.
    public func ensureModelDownloaded() async {
        let shouldStart: Bool = stateLock.withLock { state in
            guard state.cachedEngine == nil, !state.isDownloading else { return false }
            state.isDownloading = true
            return true
        }
        guard shouldStart else { return }
        await performLoad()
    }

    // MARK: - STTEngine

    public func transcribe(_ audio: SpeakKit.AudioBuffer) async throws -> SpeakKit.Transcription {
        let engine = try await loadIfNeeded()
        let forced = stateLock.withLock { $0.forcedLanguage }
        Diagnostics.log("whisperkit: transcribe(\(audio.frames.count) frames) starting, forced lang=\(forced ?? "auto")")
        let start = Date()
        let results: [TranscriptionResult]
        if let forced {
            let options = DecodingOptions(language: forced)
            results = try await engine.transcribe(audioArray: audio.frames, decodeOptions: options)
        } else {
            results = try await engine.transcribe(audioArray: audio.frames)
        }
        let elapsed = Date().timeIntervalSince(start)
        let text = results.map { $0.text }.joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let detected = results.first?.language
        Diagnostics.log("whisperkit: transcribe done in \(String(format: "%.2f", elapsed))s, \(text.count) chars, lang=\(detected ?? "?")")
        return SpeakKit.Transcription(text: text, sourceLanguage: language(for: detected))
    }

    // MARK: - Private

    private func loadIfNeeded() async throws -> WhisperKit {
        if let existing = stateLock.withLock({ $0.cachedEngine }) {
            return existing
        }
        let alreadyDownloading = stateLock.withLock { state -> Bool in
            if state.isDownloading { return true }
            state.isDownloading = true
            return false
        }
        if alreadyDownloading {
            // Wait for the ongoing download by polling.
            while true {
                try await Task.sleep(for: .milliseconds(200))
                if let engine = stateLock.withLock({ $0.cachedEngine }) {
                    return engine
                }
                if !stateLock.withLock({ $0.isDownloading }) {
                    throw WhisperKitLoadError.downloadFailed
                }
            }
        }
        await performLoad()
        if let engine = stateLock.withLock({ $0.cachedEngine }) {
            return engine
        }
        throw WhisperKitLoadError.downloadFailed
    }

    private func performLoad() async {
        let modelName = stateLock.withLock { $0.modelName }
        Diagnostics.log("whisperkit: loading model \"\(modelName)\"")
        let start = Date()

        if let localFolder = Self.localModelFolder(for: modelName) {
            Diagnostics.log("whisperkit: using local model folder \(localFolder.path)")
            do {
                let config = WhisperKitConfig(model: modelName, modelFolder: localFolder.path, verbose: false, prewarm: false, download: false)
                let engine = try await WhisperKit(config)
                let elapsed = Date().timeIntervalSince(start)
                Diagnostics.log("whisperkit: model loaded in \(String(format: "%.2f", elapsed))s")
                stateLock.withLock { state in
                    state.cachedEngine = engine
                    state.isDownloading = false
                    state.broadcast(.completed)
                    state.finishAll()
                }
            } catch {
                Diagnostics.log("whisperkit: model load failed: \(error)")
                stateLock.withLock { state in
                    state.isDownloading = false
                    state.broadcast(.failed(error.localizedDescription))
                    state.finishAll()
                }
            }
        } else {
            // Download first
            Diagnostics.log("whisperkit: downloading model \(modelName)…")
            do {
                _ = try await WhisperKit.download(variant: modelName) { [weak self] progress in
                    guard let self else { return }
                    let fraction = progress.fractionCompleted
                    self.stateLock.withLock { state in
                        state.broadcast(.downloading(fraction: fraction))
                    }
                }
                // Load after download
                let config: WhisperKitConfig
                if let folder = Self.localModelFolder(for: modelName) {
                    config = WhisperKitConfig(model: modelName, modelFolder: folder.path, verbose: false, prewarm: false, download: false)
                } else {
                    config = WhisperKitConfig(model: modelName, verbose: false, prewarm: false, download: false)
                }
                let engine = try await WhisperKit(config)
                let elapsed = Date().timeIntervalSince(start)
                Diagnostics.log("whisperkit: model downloaded and loaded in \(String(format: "%.2f", elapsed))s")
                stateLock.withLock { state in
                    state.cachedEngine = engine
                    state.isDownloading = false
                    state.broadcast(.completed)
                    state.finishAll()
                }
            } catch {
                Diagnostics.log("whisperkit: download failed: \(error)")
                stateLock.withLock { state in
                    state.isDownloading = false
                    state.broadcast(.failed(error.localizedDescription))
                    state.finishAll()
                }
            }
        }
    }

    /// Returns the on-disk model folder if WhisperKit's default HF cache already contains the required files.
    private static func localModelFolder(for modelName: String) -> URL? {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        guard let documents else { return nil }
        let folder = documents
            .appending(path: "huggingface/models/argmaxinc/whisperkit-coreml")
            .appending(path: modelName)
        let required = ["AudioEncoder.mlmodelc", "TextDecoder.mlmodelc", "MelSpectrogram.mlmodelc"]
        for name in required {
            if !FileManager.default.fileExists(atPath: folder.appending(path: name).path) {
                return nil
            }
        }
        return folder
    }

    private func language(for code: String?) -> SpeakKit.Language {
        switch code?.lowercased() {
        case "en": return .english
        case "es": return .spanish
        case .some(let other) where !other.isEmpty: return .other(other)
        default: return .other("unknown")
        }
    }

    enum WhisperKitLoadError: Error {
        case downloadFailed
    }
}

// MARK: - Engine State

/// All mutable state for WhisperKitSTTEngine, serialised by OSAllocatedUnfairLock.
private struct State {
    var modelName: String = "openai_whisper-large-v3-v20240930_turbo"
    var cachedEngine: WhisperKit? = nil
    var forcedLanguage: String? = nil
    var isDownloading: Bool = false
    var continuations: [AsyncStream<SpeakKit.DownloadProgress>.Continuation] = []

    mutating func broadcast(_ event: SpeakKit.DownloadProgress) {
        for cont in continuations {
            cont.yield(event)
        }
    }

    mutating func finishAll() {
        for cont in continuations {
            cont.finish()
        }
        continuations.removeAll()
    }
}
