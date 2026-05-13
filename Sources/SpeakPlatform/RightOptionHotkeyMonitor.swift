import AppKit
import CoreGraphics
import SpeakKit

/// Watches `.flagsChanged` events for the right-Option key.
///
/// Keycode 61 is the right-Option key. We disambiguate left vs. right Option using the
/// device-dependent flag bit `NX_DEVICERALTKEYMASK` (0x00000040) because the generic
/// `.maskAlternate` bit is set for either Option key.
public final class RightOptionHotkeyMonitor: SpeakKit.HotkeyMonitor, @unchecked Sendable {
    private static let rightOptionKeycode: Int64 = 61
    private static let rightOptionDeviceMask: UInt64 = 0x0000_0040 // NX_DEVICERALTKEYMASK

    public var onPress: (@Sendable () -> Void)?
    public var onRelease: (@Sendable () -> Void)?

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isHeld = false
    private let lock = NSLock()

    public init() {}

    public func start() {
        guard tap == nil else { return }
        let mask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        let opaqueSelf = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
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
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.runLoopSource = source
    }

    public func stop() {
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
        guard keycode == Self.rightOptionKeycode else { return }

        let flagsRaw = event.flags.rawValue
        let nowHeld = (flagsRaw & Self.rightOptionDeviceMask) != 0

        lock.lock()
        let previouslyHeld = isHeld
        isHeld = nowHeld
        lock.unlock()

        Diagnostics.log(String(format: "rOpt flagsChanged keycode=%lld flags=0x%016llx nowHeld=%@ prev=%@",
                               keycode, flagsRaw,
                               nowHeld ? "true" : "false",
                               previouslyHeld ? "true" : "false"))

        if nowHeld && !previouslyHeld {
            onPress?()
        } else if !nowHeld && previouslyHeld {
            onRelease?()
        }
    }
}
