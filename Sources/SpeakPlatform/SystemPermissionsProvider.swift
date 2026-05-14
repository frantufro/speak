@preconcurrency import AVFoundation
import ApplicationServices
import IOKit.hid
import SpeakKit

/// Real implementation of `PermissionsProvider` that calls macOS system APIs.
public final class SystemPermissionsProvider: PermissionsProvider, @unchecked Sendable {
    public init() {}

    public func status(for kind: PermissionKind) -> PermissionState {
        switch kind {
        case .microphone:
            return microphoneStatus()
        case .accessibility:
            return accessibilityStatus()
        case .inputMonitoring:
            return inputMonitoringStatus()
        }
    }

    public func request(_ kind: PermissionKind, completion: @escaping @Sendable (PermissionState) -> Void) {
        switch kind {
        case .microphone:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                completion(granted ? .granted : .denied)
            }
        case .accessibility:
            // Accessibility cannot be requested programmatically — open System Settings.
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            DispatchQueue.main.async { NSWorkspace.shared.open(url) }
            completion(accessibilityStatus())
        case .inputMonitoring:
            // IOHIDRequestAccess often returns false without ever prompting
            // for LSUIElement / agent apps. Fall back to opening the System
            // Settings pane so the user can toggle the switch themselves.
            let granted = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
            if !granted {
                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
                DispatchQueue.main.async { NSWorkspace.shared.open(url) }
            }
            completion(granted ? .granted : .denied)
        }
    }

    // MARK: - Private helpers

    private func microphoneStatus() -> PermissionState {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return .granted
        case .notDetermined: return .notDetermined
        case .denied, .restricted: return .denied
        @unknown default: return .denied
        }
    }

    private func accessibilityStatus() -> PermissionState {
        AXIsProcessTrusted() ? .granted : .denied
    }

    private func inputMonitoringStatus() -> PermissionState {
        switch IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) {
        case kIOHIDAccessTypeGranted: return .granted
        case kIOHIDAccessTypeUnknown: return .notDetermined
        default: return .denied
        }
    }
}

// Needed for NSWorkspace in SpeakPlatform
import AppKit
