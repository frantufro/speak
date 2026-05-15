import Foundation

public final class ClipboardPasteboardInjector: PasteboardInjector, @unchecked Sendable {
    private let pasteboard: Pasteboard
    private let adapter: InjectionAdapter
    private let pasteDelay: Duration
    public weak var secureInputToastDelegate: (any SecureInputToastDelegate)?

    public init(
        pasteboard: Pasteboard,
        adapter: InjectionAdapter,
        pasteDelay: Duration = .milliseconds(80)
    ) {
        self.pasteboard = pasteboard
        self.adapter = adapter
        self.pasteDelay = pasteDelay
    }

    public func inject(_ text: String) async throws {
        guard !text.isEmpty else { return }
        guard !adapter.isSecureInputEnabled else {
            if let delegate = secureInputToastDelegate {
                delegate.secureInputDidBlockInjection()
            } else {
                Diagnostics.log("refusing injection — secure input is enabled")
            }
            return
        }
        let saved = pasteboard.snapshot()
        pasteboard.writeString(text)
        adapter.triggerPaste()
        try await Task.sleep(for: pasteDelay)
        pasteboard.write(saved)
    }
}
