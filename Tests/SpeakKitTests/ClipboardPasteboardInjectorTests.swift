import XCTest
@testable import SpeakKit

final class ClipboardPasteboardInjectorTests: XCTestCase {
    func test_injectText_writesThenRestoresPreviousString() async throws {
        let pasteboard = InMemoryPasteboard()
        pasteboard.writeString("original-clipboard")
        let keystroke = SpyKeystrokeSynthesizer()
        let secureInput = FakeSecureInputDetector(enabled: false)

        let injector = ClipboardPasteboardInjector(
            pasteboard: pasteboard,
            keystroke: keystroke,
            secureInput: secureInput,
            pasteDelay: .milliseconds(5)
        )

        try await injector.inject("hello")

        XCTAssertEqual(keystroke.sendCount, 1, "⌘V must be synthesized exactly once")
        XCTAssertEqual(pasteboard.snapshot().first?.asString, "original-clipboard",
                       "Previous pasteboard string must be restored after the paste")
    }

    func test_injectText_restoresRichPasteboardContents() async throws {
        let pasteboard = InMemoryPasteboard()
        let pngBytes = Data([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])
        let originalImage = PasteboardItem(types: ["public.png": pngBytes])
        let originalFileURL = PasteboardItem(types: [
            "public.file-url": "file:///tmp/x.txt".data(using: .utf8)!
        ])
        pasteboard.write([originalImage, originalFileURL])

        let injector = ClipboardPasteboardInjector(
            pasteboard: pasteboard,
            keystroke: SpyKeystrokeSynthesizer(),
            secureInput: FakeSecureInputDetector(enabled: false),
            pasteDelay: .milliseconds(5)
        )

        try await injector.inject("hello")

        let restored = pasteboard.snapshot()
        XCTAssertEqual(restored, [originalImage, originalFileURL],
                       "All NSPasteboardItem types must be restored verbatim, not flattened to text")
    }

    func test_injectEmptyString_doesNotTouchPasteboardOrSynthesize() async throws {
        let pasteboard = InMemoryPasteboard()
        let original = PasteboardItem.text("untouched")
        pasteboard.write([original])
        let keystroke = SpyKeystrokeSynthesizer()

        let injector = ClipboardPasteboardInjector(
            pasteboard: pasteboard,
            keystroke: keystroke,
            secureInput: FakeSecureInputDetector(enabled: false),
            pasteDelay: .milliseconds(5)
        )

        try await injector.inject("")

        XCTAssertEqual(keystroke.sendCount, 0, "Empty injection must not synthesize ⌘V")
        XCTAssertEqual(pasteboard.snapshot(), [original],
                       "Empty injection must leave the pasteboard untouched")
    }

    func test_secureInputEnabled_skipsPasteAndLeavesPasteboardAlone() async throws {
        let pasteboard = InMemoryPasteboard()
        let original = PasteboardItem.text("untouched")
        pasteboard.write([original])
        let keystroke = SpyKeystrokeSynthesizer()
        let secureInput = FakeSecureInputDetector(enabled: true)

        let injector = ClipboardPasteboardInjector(
            pasteboard: pasteboard,
            keystroke: keystroke,
            secureInput: secureInput,
            pasteDelay: .milliseconds(5)
        )

        try await injector.inject("hello")

        XCTAssertEqual(keystroke.sendCount, 0, "Secure input must short-circuit ⌘V synthesis")
        XCTAssertEqual(pasteboard.snapshot(), [original],
                       "Secure input must leave the pasteboard untouched")
    }

    func test_secureInputEnabled_callsToastDelegate() async throws {
        let pasteboard = InMemoryPasteboard()
        pasteboard.write([.text("original")])
        let secureInput = FakeSecureInputDetector(enabled: true)
        let injector = ClipboardPasteboardInjector(
            pasteboard: pasteboard,
            keystroke: SpyKeystrokeSynthesizer(),
            secureInput: secureInput,
            pasteDelay: .milliseconds(5)
        )

        let delegate = SpyToastDelegate()
        injector.secureInputToastDelegate = delegate

        try await injector.inject("hello")

        XCTAssertEqual(delegate.callCount, 1, "Toast delegate must be notified once for a secure-input block")
    }
}
