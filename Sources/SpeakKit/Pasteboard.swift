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
