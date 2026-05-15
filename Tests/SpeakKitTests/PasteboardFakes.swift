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

final class FakeInjectionAdapter: InjectionAdapter, @unchecked Sendable {
    private let lock = NSLock()
    private var _pasteCount = 0
    private var _isSecureInputEnabled: Bool

    init(secureInputEnabled: Bool = false) {
        self._isSecureInputEnabled = secureInputEnabled
    }

    var pasteCount: Int { lock.withLock { _pasteCount } }

    var isSecureInputEnabled: Bool {
        lock.withLock { _isSecureInputEnabled }
    }

    func triggerPaste() {
        lock.withLock { _pasteCount += 1 }
    }

    func setSecureInputEnabled(_ value: Bool) {
        lock.withLock { _isSecureInputEnabled = value }
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
