import Foundation
import SpeakKit
@preconcurrency import WhisperKit
import os

/// Adapter over WhisperKit. The engine is loaded lazily on the first transcription
/// so the menu-bar shell starts instantly; first-press latency is dominated by load+specialize.
///
/// WhisperKit itself is not `Sendable`, so this wrapper is marked `@unchecked Sendable`.
public final class WhisperKitSTTEngine: SpeakKit.STTEngine, @unchecked Sendable {
    private let modelName: String
    private let cached: OSAllocatedUnfairLock<WhisperKit?> = .init(initialState: nil)

    public init(modelName: String = "openai_whisper-large-v3-v20240930_turbo") {
        self.modelName = modelName
    }

    public func transcribe(_ audio: SpeakKit.AudioBuffer) async throws -> SpeakKit.Transcription {
        let engine = try await loadIfNeeded()
        Diagnostics.log("whisperkit: transcribe(\(audio.frames.count) frames) starting")
        let start = Date()
        let results = try await engine.transcribe(audioArray: audio.frames)
        let elapsed = Date().timeIntervalSince(start)
        let text = results.map { $0.text }.joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let detected = results.first?.language
        Diagnostics.log("whisperkit: transcribe done in \(String(format: "%.2f", elapsed))s, \(text.count) chars, lang=\(detected ?? "?")")
        return SpeakKit.Transcription(text: text, sourceLanguage: language(for: detected))
    }

    private func loadIfNeeded() async throws -> WhisperKit {
        if let existing = cached.withLock({ $0 }) {
            return existing
        }
        Diagnostics.log("whisperkit: loading model \"\(modelName)\" (first use can take 30s–2min)")
        let start = Date()
        let localFolder = Self.localModelFolder(for: modelName)
        let config: WhisperKitConfig
        if let localFolder {
            Diagnostics.log("whisperkit: using local model folder \(localFolder.path)")
            config = WhisperKitConfig(model: modelName, modelFolder: localFolder.path, verbose: false, prewarm: false, download: false)
        } else {
            config = WhisperKitConfig(model: modelName, verbose: false, prewarm: false)
        }
        let engine = try await WhisperKit(config)
        Diagnostics.log("whisperkit: model loaded in \(String(format: "%.2f", Date().timeIntervalSince(start)))s")
        cached.withLock { $0 = engine }
        return engine
    }

    /// Returns the on-disk model folder if WhisperKit's default HF cache already contains the required files.
    /// This lets us bypass the HubApi download path entirely when the model is already present.
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
}
