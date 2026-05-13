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
        let results = try await engine.transcribe(audioArray: audio.frames)
        let text = results.map { $0.text }.joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let detected = results.first?.language
        return SpeakKit.Transcription(text: text, sourceLanguage: language(for: detected))
    }

    private func loadIfNeeded() async throws -> WhisperKit {
        if let existing = cached.withLock({ $0 }) {
            return existing
        }
        let config = WhisperKitConfig(model: modelName, verbose: false, prewarm: false)
        let engine = try await WhisperKit(config)
        cached.withLock { $0 = engine }
        return engine
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
