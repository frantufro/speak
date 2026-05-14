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

final class SpyToastDelegate: SecureInputToastDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var _callCount = 0
    var callCount: Int { lock.withLock { _callCount } }

    func secureInputDidBlockInjection() {
        lock.withLock { _callCount += 1 }
    }
}
