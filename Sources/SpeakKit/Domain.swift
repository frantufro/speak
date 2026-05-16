import Foundation

public struct AudioBuffer: Sendable, Equatable {
    public let frames: [Float]
    public init(frames: [Float]) { self.frames = frames }
    public var isEmpty: Bool { frames.isEmpty }
}

/// Snapshot of whether an STT engine is ready to transcribe right now.
public enum ModelState: Sendable, Equatable {
    case ready
    case notReady(NotReadyReason)

    public var isReady: Bool {
        if case .ready = self { return true } else { return false }
    }
}

/// The reason an STT engine is not yet ready to transcribe.
public enum NotReadyReason: Sendable, Equatable {
    case checking
    case downloading(fraction: Double)
    case failed(message: String)
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
