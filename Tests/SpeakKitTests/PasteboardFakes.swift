import Foundation
@testable import SpeakKit

final class InMemoryPasteboard: Pasteboard, @unchecked Sendable {
    private let lock = NSLock()
    private var items: [PasteboardItem] = []

    func snapshot() -> [PasteboardItem] {
        lock.withLock { items }
    }

    func write(_ items: [PasteboardItem]) {
        lock.withLock { self.items = items }
    }

    func writeString(_ text: String) {
        write([.text(text)])
    }
}

final class SpyKeystrokeSynthesizer: KeystrokeSynthesizer, @unchecked Sendable {
    private let lock = NSLock()
    private var _sendCount = 0
    var sendCount: Int { lock.withLock { _sendCount } }

    func sendCommandV() {
        lock.withLock { _sendCount += 1 }
    }
}

final class FakeSecureInputDetector: SecureInputDetector, @unchecked Sendable {
    private let lock = NSLock()
    private var _isEnabled: Bool

    init(enabled: Bool = false) {
        self._isEnabled = enabled
    }

    var isSecureInputEnabled: Bool {
        lock.withLock { _isEnabled }
    }

    func setEnabled(_ value: Bool) {
        lock.withLock { _isEnabled = value }
    }
}
