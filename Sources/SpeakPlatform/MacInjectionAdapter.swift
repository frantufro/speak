import AppKit
import Carbon.HIToolbox
import CoreGraphics
import SpeakKit

public final class MacInjectionAdapter: InjectionAdapter, @unchecked Sendable {
    public init() {}

    public func triggerPaste() {
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

    public var isSecureInputEnabled: Bool {
        IsSecureEventInputEnabled()
    }
}
