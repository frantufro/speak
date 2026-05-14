import Foundation

public final class ClipboardPasteboardInjector: PasteboardInjector, @unchecked Sendable {
    private let pasteboard: Pasteboard
    private let keystroke: KeystrokeSynthesizer
    private let secureInput: SecureInputDetector
    private let pasteDelay: Duration
    public weak var secureInputToastDelegate: (any SecureInputToastDelegate)?

    public init(
        pasteboard: Pasteboard,
        keystroke: KeystrokeSynthesizer,
        secureInput: SecureInputDetector,
        pasteDelay: Duration = .milliseconds(80)
    ) {
        self.pasteboard = pasteboard
        self.keystroke = keystroke
        self.secureInput = secureInput
        self.pasteDelay = pasteDelay
    }

    public func inject(_ text: String) async throws {
        guard !text.isEmpty else { return }
        guard !secureInput.isSecureInputEnabled else {
            if let delegate = secureInputToastDelegate {
                delegate.secureInputDidBlockInjection()
            } else {
                Diagnostics.log("refusing injection — secure input is enabled")
            }
            return
        }
        let saved = pasteboard.snapshot()
        pasteboard.writeString(text)
        keystroke.sendCommandV()
        try await Task.sleep(for: pasteDelay)
        pasteboard.write(saved)
    }
}
