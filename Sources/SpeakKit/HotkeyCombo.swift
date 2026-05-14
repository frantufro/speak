import Foundation

/// A key + modifier combination that identifies a hotkey.
///
/// `keyCode` is the virtual key code (e.g. 61 = right-Option).
/// `modifierFlags` is the raw `CGEventFlags` value for any required modifier bits
/// (e.g. `NX_DEVICERALTKEYMASK` = 0x0000_0040 for right-Option).
/// Use 0 for `modifierFlags` when a bare key (no modifiers) should trigger the hotkey.
public struct HotkeyCombo: Sendable, Equatable, Codable {
    public let keyCode: Int64
    /// Raw `CGEventFlags` mask. Only the bits you supply must be set in the incoming event.
    public let modifierFlags: UInt64

    public init(keyCode: Int64, modifierFlags: UInt64) {
        self.keyCode = keyCode
        self.modifierFlags = modifierFlags
    }

    /// The default: right-Option (keycode 61, NX_DEVICERALTKEYMASK).
    public static let rightOption = HotkeyCombo(keyCode: 61, modifierFlags: 0x0000_0040)
}
