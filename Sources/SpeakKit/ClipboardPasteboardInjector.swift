import Foundation

public final class ClipboardPasteboardInjector: PasteboardInjector {
    private let pasteboard: Pasteboard
    private let keystroke: KeystrokeSynthesizer
    private let secureInput: SecureInputDetector
    private let pasteDelay: Duration

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
            FileHandle.standardError.write(
                Data("speak: refusing Injection — secure input is enabled\n".utf8)
            )
            return
        }
        let saved = pasteboard.snapshot()
        pasteboard.writeString(text)
        keystroke.sendCommandV()
        try await Task.sleep(for: pasteDelay)
        pasteboard.write(saved)
    }
}
