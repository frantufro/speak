/// STT Engine Contract Tests
///
/// These tests load a real WhisperKit model and transcribe fixture WAV files.
/// They are **opt-in** and excluded from the default `swift test` run.
///
/// # How to run
///
/// 1. Ensure fixture WAVs exist (committed to the repo; regenerate with `bin/fetch-test-fixtures`).
/// 2. Set the environment variable and run with a target filter:
///
///    ```
///    SPEAK_CONTRACT_TESTS=1 swift test --filter STTContractTests
///    ```
///
/// The tests use the `openai_whisper-tiny` model for speed. WhisperKit will download
/// it on first run (requires internet; ~75 MB). Subsequent runs use the local cache.

import XCTest
import SpeakSTT
import SpeakKit

final class STTContractTests: XCTestCase {

    // MARK: - Setup

    // One engine per test method — simple and avoids shared mutable state.
    private func makeEngine() -> WhisperKitSTTEngine {
        WhisperKitSTTEngine(modelName: "openai_whisper-tiny")
    }

    // MARK: - Helpers

    private func optInOrSkip() throws {
        guard ProcessInfo.processInfo.environment["SPEAK_CONTRACT_TESTS"] == "1" else {
            throw XCTSkip("Contract tests are opt-in. Run with SPEAK_CONTRACT_TESTS=1 swift test --filter STTContractTests")
        }
    }

    private func fixtureURL(named name: String) throws -> URL {
        // When run via `swift test`, the test bundle's resources are adjacent to the binary.
        // We fall back to looking relative to the source file.
        let candidates: [URL] = [
            Bundle(for: STTContractTests.self)
                .url(forResource: name, withExtension: "wav"),
            URL(fileURLWithPath: #file)
                .deletingLastPathComponent()
                .appendingPathComponent("Fixtures/\(name).wav"),
        ].compactMap { $0 }

        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        throw XCTSkip("Fixture '\(name).wav' not found. Run bin/fetch-test-fixtures first.")
    }

    private func loadAudio(from url: URL) throws -> AudioBuffer {
        let data = try Data(contentsOf: url)
        // Skip the 44-byte WAV header and read 16-bit PCM samples.
        let headerSize = 44
        guard data.count > headerSize else {
            return AudioBuffer(frames: [])
        }
        let pcmData = data.dropFirst(headerSize)
        var frames: [Float] = []
        frames.reserveCapacity(pcmData.count / 2)
        var idx = pcmData.startIndex
        while idx < pcmData.endIndex {
            let next = pcmData.index(idx, offsetBy: 2, limitedBy: pcmData.endIndex) ?? pcmData.endIndex
            guard next <= pcmData.endIndex else { break }
            let sample = pcmData[idx ..< next].withUnsafeBytes { ptr -> Int16 in
                ptr.loadUnaligned(as: Int16.self)
            }
            frames.append(Float(sample) / 32768.0)
            idx = next
        }
        return AudioBuffer(frames: frames)
    }

    // MARK: - Tests

    func test_englishClip_containsExpectedWords() async throws {
        try optInOrSkip()
        let url = try fixtureURL(named: "english")
        let audio = try loadAudio(from: url)
        let result = try await makeEngine().transcribe(audio)
        let lower = result.text.lowercased()
        // The fixture says "The weather is nice today and the sun is shining"
        XCTAssertTrue(lower.contains("weather") || lower.contains("sun") || lower.contains("today"),
                      "Expected English words in transcript; got: '\(result.text)'")
    }

    func test_spanishClip_containsExpectedWordsAndDetectedLanguageIsSpanish() async throws {
        try optInOrSkip()
        let url = try fixtureURL(named: "spanish")
        let audio = try loadAudio(from: url)
        let result = try await makeEngine().transcribe(audio)
        let lower = result.text.lowercased()
        // The fixture says "El clima es muy bueno hoy en Buenos Aires"
        XCTAssertTrue(lower.contains("clima") || lower.contains("buenos") || lower.contains("bueno"),
                      "Expected Spanish words in transcript; got: '\(result.text)'")
        XCTAssertEqual(result.sourceLanguage, .spanish,
                       "Expected detected language to be Spanish; got: \(String(describing: result.sourceLanguage))")
    }

    func test_silenceClip_producesEmptyOrNearEmptyTranscript() async throws {
        try optInOrSkip()
        let url = try fixtureURL(named: "silence")
        let audio = try loadAudio(from: url)
        let result = try await makeEngine().transcribe(audio)
        let trimmed = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Allow up to 10 characters for hallucinations on silence
        XCTAssertTrue(trimmed.count <= 10,
                      "Expected near-empty transcript for silence; got: '\(trimmed)'")
    }

    func test_shortUtterance_producesNonEmptyTranscript() async throws {
        try optInOrSkip()
        let url = try fixtureURL(named: "short")
        let audio = try loadAudio(from: url)
        let result = try await makeEngine().transcribe(audio)
        let trimmed = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertFalse(trimmed.isEmpty,
                       "Expected non-empty transcript for short utterance")
    }
}
