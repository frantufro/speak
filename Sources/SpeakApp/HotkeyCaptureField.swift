import AppKit
import SwiftUI
import SpeakKit

/// A button-like control that, when clicked, listens for the next key event (with optional
/// modifiers) and reports it as a `HotkeyCombo`.
///
/// Modifier-only keys (Control, Shift, Option, Command, Fn) pressed alone are valid hotkeys
/// and are captured via `flagsChanged` events; all other keys are captured via `keyDown`.
struct HotkeyCaptureField: NSViewRepresentable {
    @Binding var combo: HotkeyCombo
    @Binding var isCapturing: Bool

    func makeNSView(context: Context) -> HotkeyCaptureButton {
        let btn = HotkeyCaptureButton()
        btn.onCombo = { [weak btn] newCombo in
            combo = newCombo
            isCapturing = false
            btn?.stopCapture()
        }
        btn.onCapturingChanged = { capturing in
            isCapturing = capturing
        }
        return btn
    }

    func updateNSView(_ nsView: HotkeyCaptureButton, context: Context) {
        nsView.currentCombo = combo
        nsView.refreshTitle()
    }
}

/// An `NSButton` subclass that handles hotkey capture.
final class HotkeyCaptureButton: NSButton {
    var onCombo: ((HotkeyCombo) -> Void)?
    var onCapturingChanged: ((Bool) -> Void)?
    var currentCombo: HotkeyCombo = .rightOption

    private var capturing = false
    private var localMonitor: Any?
    private var flagsMonitor: Any?

    override init(frame: NSRect) {
        super.init(frame: frame)
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(beginCapture)
        refreshTitle()
    }

    required init?(coder: NSCoder) { fatalError() }

    func refreshTitle() {
        title = capturing ? "… press a key" : label(for: currentCombo)
    }

    func stopCapture() {
        capturing = false
        refreshTitle()
        removeMonitors()
    }

    @objc private func beginCapture() {
        guard !capturing else { stopCapture(); return }
        capturing = true
        onCapturingChanged?(true)
        refreshTitle()
        installMonitors()
    }

    private func installMonitors() {
        // Capture modifier-only keys (Option, Control, Fn, etc.)
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlags(event)
            return nil // consume
        }
        // Capture regular keys
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == 53 { // Escape — cancel
                self.stopCapture()
                self.onCapturingChanged?(false)
                return nil
            }
            let flags = event.modifierFlags.rawValue & ~NSEvent.ModifierFlags.numericPad.rawValue
            let combo = HotkeyCombo(keyCode: Int64(event.keyCode), modifierFlags: UInt64(flags))
            self.onCombo?(combo)
            return nil
        }
    }

    private func handleFlags(_ event: NSEvent) {
        // Only commit a modifier-only combo when the user has at least one modifier held
        // and it looks like they pressed a dedicated modifier key (Fn, Option, Control, etc.)
        // We detect release so we get the combo *after* they pressed.
        let flags = event.modifierFlags.intersection([.option, .control, .command, .shift, .function])
        guard flags.isEmpty else { return } // still holding — wait for release
        // On release, the last modifier they used is no longer in flags.
        // Use the device-specific bits from the CGEvent to identify *which* key.
        // For simplicity, map common solo-modifier key codes:
        let kc = event.keyCode
        let deviceMask = deviceMaskForKeyCode(kc)
        guard deviceMask != 0 || isBareKeyCode(kc) else { return }
        let combo = HotkeyCombo(keyCode: Int64(kc), modifierFlags: deviceMask)
        onCombo?(combo)
    }

    private func removeMonitors() {
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
        if let m = flagsMonitor { NSEvent.removeMonitor(m); flagsMonitor = nil }
    }

    // MARK: – Helpers

    private func label(for combo: HotkeyCombo) -> String {
        switch combo.keyCode {
        case 61: return "⌥ (Right Option)"
        case 58: return "⌥ (Left Option)"
        case 59: return "^ (Left Control)"
        case 62: return "^ (Right Control)"
        case 56: return "⇧ (Left Shift)"
        case 60: return "⇧ (Right Shift)"
        case 55: return "⌘ (Left Command)"
        case 54: return "⌘ (Right Command)"
        case 63: return "fn"
        default:
            let mods = NSEvent.ModifierFlags(rawValue: UInt(combo.modifierFlags))
            let modStr = modString(mods)
            let keyStr = keyName(keyCode: UInt16(combo.keyCode))
            return "\(modStr)\(keyStr)"
        }
    }

    private func modString(_ flags: NSEvent.ModifierFlags) -> String {
        var s = ""
        if flags.contains(.control) { s += "^" }
        if flags.contains(.option) { s += "⌥" }
        if flags.contains(.shift) { s += "⇧" }
        if flags.contains(.command) { s += "⌘" }
        return s
    }

    private func keyName(keyCode: UInt16) -> String {
        // Map common key codes to readable names
        let map: [UInt16: String] = [
            36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "Esc",
            123: "←", 124: "→", 125: "↓", 126: "↑",
        ]
        return map[keyCode] ?? "Key\(keyCode)"
    }

    /// Returns the `CGEventFlags` device-specific mask bit for a modifier key code, or 0.
    private func deviceMaskForKeyCode(_ kc: UInt16) -> UInt64 {
        switch kc {
        case 61: return 0x0000_0040  // NX_DEVICERALTKEYMASK — right Option
        case 58: return 0x0000_0020  // NX_DEVICELALTKEYMASK — left Option
        case 59: return 0x0000_0001  // NX_DEVICELCTLKEYMASK — left Control
        case 62: return 0x0000_2000  // NX_DEVICERCTLKEYMASK — right Control
        case 56: return 0x0000_0002  // NX_DEVICELSHIFTKEYMASK — left Shift
        case 60: return 0x0000_0004  // NX_DEVICERSHIFTKEYMASK — right Shift
        case 55: return 0x0000_0008  // NX_DEVICELCMDKEYMASK — left Command
        case 54: return 0x0000_0010  // NX_DEVICERCMDKEYMASK — right Command
        case 63: return 0x0000_0080  // NX_DEVICELFNKEYMASK — Fn
        default: return 0
        }
    }

    private func isBareKeyCode(_ kc: UInt16) -> Bool {
        // Fn (63) is a valid bare-key hotkey even without a device mask
        kc == 63
    }
}
