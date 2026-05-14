import Foundation

public struct AudioBuffer: Sendable, Equatable {
    public let frames: [Float]
    public init(frames: [Float]) { self.frames = frames }
    public var isEmpty: Bool { frames.isEmpty }
}

/// Progress event emitted while a Whisper model is being downloaded.
public enum DownloadProgress: Sendable, Equatable {
    /// Download is in progress. `fraction` is in 0.0 … 1.0.
    case downloading(fraction: Double)
    /// Download completed successfully.
    case completed
    /// Download failed.
    case failed(String)
}

public enum Language: Sendable, Equatable {
    case english
    case spanish
    case other(String)
}

public struct Transcription: Sendable, Equatable {
    public let text: String
    public let sourceLanguage: Language?
    public init(text: String, sourceLanguage: Language? = nil) {
        self.text = text
        self.sourceLanguage = sourceLanguage
    }
}
