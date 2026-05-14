import AppKit
import ApplicationServices
import CoreGraphics
import IOKit.hid
import SpeakKit

/// Watches `.flagsChanged` events for a configurable hotkey combo.
///
/// The default combo is right-Option (keycode 61, `NX_DEVICERALTKEYMASK` = 0x00000040).
/// Call `rebind(_:)` at any time to switch to a different combo; the event tap is torn down
/// and re-installed so the new combo takes effect immediately.
public final class RightOptionHotkeyMonitor: SpeakKit.HotkeyMonitor, @unchecked Sendable {
    public var onPress: (@Sendable () -> Void)?
    public var onRelease: (@Sendable () -> Void)?

    private var combo: HotkeyCombo
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isHeld = false
    private let lock = NSLock()

    public init(combo: HotkeyCombo = .rightOption) {
        self.combo = combo
    }

    public func start() {
        guard tap == nil else { return }
        installTap()
    }

    public func stop() {
        tearDownTap()
    }

    public func rebind(_ newCombo: HotkeyCombo) {
        lock.lock()
        let wasRunning = tap != nil
        combo = newCombo
        isHeld = false          // reset held state so we don't fire a phantom release
        lock.unlock()

        if wasRunning {
            tearDownTap()
            installTap()
        }
    }

    // MARK: – Private

    private func installTap() {
        // kAXTrustedCheckOptionPrompt's documented string value.
        let options: NSDictionary = ["AXTrustedCheckOptionPrompt": true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        Diagnostics.log("AX trusted (event-tap permission): \(trusted)")
        if !trusted {
            Diagnostics.log("→ macOS Accessibility approval prompt should now be visible.")
            Diagnostics.log("→ click \"Open System Settings\", toggle speak on, then quit and relaunch speak.")
        }
        let listenAccess = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
        Diagnostics.log("Input Monitoring access: \(listenAccess.rawValue) (0=granted, 1=denied, 2=unknown)")
        if listenAccess != kIOHIDAccessTypeGranted {
            Diagnostics.log("→ requesting Input Monitoring permission (a dialog should appear)")
            let granted = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
            Diagnostics.log("Input Monitoring prompt result: granted=\(granted)")
            if !granted {
                Diagnostics.log("→ open System Settings → Privacy & Security → Input Monitoring, toggle speak on, then quit and relaunch.")
            }
        }
        let mask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        let opaqueSelf = Unmanaged.passUnretained(self).toOpaque()
        guard let newTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<RightOptionHotkeyMonitor>.fromOpaque(userInfo).takeUnretainedValue()
                monitor.handle(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: opaqueSelf
        ) else {
            FileHandle.standardError.write(
                Data("speak: failed to create event tap — Accessibility permission likely missing\n".utf8)
            )
            return
        }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)
        tap = newTap
        runLoopSource = source
    }

    private func tearDownTap() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        tap = nil
        runLoopSource = nil
    }

    private func handle(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            Diagnostics.log("event tap disabled (\(type)) — re-enabling")
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        guard type == .flagsChanged else { return }
        let keycode = event.getIntegerValueField(.keyboardEventKeycode)
        let flagsRaw = event.flags.rawValue
        Diagnostics.log(String(format: "flagsChanged keycode=%lld flags=0x%016llx", keycode, flagsRaw))

        lock.lock()
        let currentCombo = combo
        lock.unlock()

        guard keycode == currentCombo.keyCode else { return }

        let nowHeld: Bool
        if currentCombo.modifierFlags == 0 {
            // Bare key: treat the keydown as the trigger event.
            // flagsChanged with the key's bit in the flags = pressed.
            // We can't distinguish pressed vs released for bare keys without device mask,
            // so for bare-key combos we rely on the event having any non-zero flags going up
            // and zero going down. This is good enough for single-modifier keys used alone.
            nowHeld = flagsRaw != 0
        } else {
            nowHeld = (flagsRaw & currentCombo.modifierFlags) != 0
        }

        lock.lock()
        let previouslyHeld = isHeld
        isHeld = nowHeld
        lock.unlock()

        Diagnostics.log(String(format: "hotkey nowHeld=%@ prev=%@",
                               nowHeld ? "true" : "false",
                               previouslyHeld ? "true" : "false"))

        if nowHeld && !previouslyHeld {
            onPress?()
        } else if !nowHeld && previouslyHeld {
            onRelease?()
        }
    }
}
