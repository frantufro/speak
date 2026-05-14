import Foundation

public struct PasteboardItem: Sendable, Equatable {
    public let types: [String: Data]
    public init(types: [String: Data]) { self.types = types }
}

public protocol Pasteboard: AnyObject, Sendable {
    func snapshot() -> [PasteboardItem]
    func write(_ items: [PasteboardItem])
    func writeString(_ text: String)
}

public protocol KeystrokeSynthesizer: AnyObject, Sendable {
    func sendCommandV()
}

public protocol SecureInputDetector: AnyObject, Sendable {
    var isSecureInputEnabled: Bool { get }
}

/// Receives a notification when injection is blocked by secure input.
/// The injector calls this instead of writing to stderr so the app layer
/// can surface the message however it likes (e.g. a toast).
public protocol SecureInputToastDelegate: AnyObject, Sendable {
    func secureInputDidBlockInjection()
}

public extension PasteboardItem {
    static let utf8TextType = "public.utf8-plain-text"

    static func text(_ string: String) -> PasteboardItem {
        let data = string.data(using: .utf8) ?? Data()
        return PasteboardItem(types: [utf8TextType: data])
    }

    var asString: String? {
        guard let data = types[Self.utf8TextType] else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
