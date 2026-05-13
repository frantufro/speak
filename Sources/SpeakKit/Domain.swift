import Foundation

public struct AudioBuffer: Sendable, Equatable {
    public let frames: [Float]
    public init(frames: [Float]) { self.frames = frames }
    public var isEmpty: Bool { frames.isEmpty }
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
