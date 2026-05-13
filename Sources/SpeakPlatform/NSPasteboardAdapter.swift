import AppKit
import SpeakKit

public final class NSPasteboardAdapter: SpeakKit.Pasteboard, @unchecked Sendable {
    private let pasteboard: NSPasteboard

    public init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    public func snapshot() -> [SpeakKit.PasteboardItem] {
        guard let items = pasteboard.pasteboardItems else { return [] }
        return items.map { item in
            var types: [String: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    types[type.rawValue] = data
                }
            }
            return SpeakKit.PasteboardItem(types: types)
        }
    }

    public func write(_ items: [SpeakKit.PasteboardItem]) {
        pasteboard.clearContents()
        let nsItems = items.map { item -> NSPasteboardItem in
            let nsItem = NSPasteboardItem()
            for (typeString, data) in item.types {
                nsItem.setData(data, forType: NSPasteboard.PasteboardType(typeString))
            }
            return nsItem
        }
        pasteboard.writeObjects(nsItems)
    }

    public func writeString(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
