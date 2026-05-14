import Foundation

// MARK: - Domain types

public enum PermissionKind: CaseIterable, Sendable, Equatable {
    case microphone
    case accessibility
    case inputMonitoring
}

public enum PermissionState: Sendable, Equatable {
    case notDetermined
    case granted
    case denied
}

public struct PermissionsStatus: Sendable, Equatable {
    public let microphone: PermissionState
    public let accessibility: PermissionState
    public let inputMonitoring: PermissionState

    public init(
        microphone: PermissionState,
        accessibility: PermissionState,
        inputMonitoring: PermissionState
    ) {
        self.microphone = microphone
        self.accessibility = accessibility
        self.inputMonitoring = inputMonitoring
    }

    public var allGranted: Bool {
        microphone == .granted && accessibility == .granted && inputMonitoring == .granted
    }

    /// Returns the first permission that is not yet granted, in the order the
    /// onboarding window presents them.
    public var firstMissing: PermissionKind? {
        if microphone != .granted { return .microphone }
        if accessibility != .granted { return .accessibility }
        if inputMonitoring != .granted { return .inputMonitoring }
        return nil
    }
}

// MARK: - Provider protocol (platform-agnostic for testing)

public protocol PermissionsProvider: AnyObject, Sendable {
    func status(for kind: PermissionKind) -> PermissionState
    /// Request the permission. Calls `completion` with the result.
    func request(_ kind: PermissionKind, completion: @escaping @Sendable (PermissionState) -> Void)
}

// MARK: - Service

/// Provides a stable snapshot of the current permissions and lets the rest of
/// the app request individual permissions. Notifies observers when the status
/// changes by publishing via `statusDidChange`.
public final class PermissionsService: @unchecked Sendable {
    private let provider: PermissionsProvider
    private let lock = NSLock()
    private var _current: PermissionsStatus

    public var statusDidChange: (@Sendable (PermissionsStatus) -> Void)?

    public init(provider: PermissionsProvider) {
        self.provider = provider
        _current = Self.snapshot(from: provider)
    }

    public func current() -> PermissionsStatus {
        lock.withLock { _current }
    }

    /// Re-reads the current status from the provider and fires `statusDidChange`
    /// if anything changed. Call this after returning from System Settings.
    public func refresh() {
        let fresh = Self.snapshot(from: provider)
        let changed: Bool = lock.withLock {
            let changed = _current != fresh
            _current = fresh
            return changed
        }
        if changed { statusDidChange?(fresh) }
    }

    public func request(_ kind: PermissionKind, completion: @escaping @Sendable (PermissionState) -> Void) {
        provider.request(kind) { [weak self] state in
            self?.refresh()
            completion(state)
        }
    }

    private static func snapshot(from provider: PermissionsProvider) -> PermissionsStatus {
        PermissionsStatus(
            microphone: provider.status(for: .microphone),
            accessibility: provider.status(for: .accessibility),
            inputMonitoring: provider.status(for: .inputMonitoring)
        )
    }
}
