import AppKit
import Carbon.HIToolbox
import CoreGraphics
import SpeakKit

public final class CGEventKeystrokeSynthesizer: SpeakKit.KeystrokeSynthesizer, @unchecked Sendable {
    public init() {}

    public func sendCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKeyCode = CGKeyCode(kVK_ANSI_V)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            return
        }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}

public final class MacSecureInputDetector: SpeakKit.SecureInputDetector, @unchecked Sendable {
    public init() {}

    public var isSecureInputEnabled: Bool {
        IsSecureEventInputEnabled()
    }
}
