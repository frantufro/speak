import XCTest
@testable import SpeakKit

// MARK: - Fake provider

final class FakePermissionsProvider: PermissionsProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var _states: [PermissionKind: PermissionState]

    init(_ states: [PermissionKind: PermissionState] = [:]) {
        var defaults: [PermissionKind: PermissionState] = [:]
        for kind in PermissionKind.allCases {
            defaults[kind] = .notDetermined
        }
        for (k, v) in states { defaults[k] = v }
        _states = defaults
    }

    func status(for kind: PermissionKind) -> PermissionState {
        lock.withLock { _states[kind] ?? .notDetermined }
    }

    func set(_ kind: PermissionKind, to state: PermissionState) {
        lock.withLock { _states[kind] = state }
    }

    func request(_ kind: PermissionKind, completion: @escaping @Sendable (PermissionState) -> Void) {
        // Simulate immediate grant
        set(kind, to: .granted)
        completion(.granted)
    }
}

// MARK: - Tests

final class PermissionsServiceTests: XCTestCase {
    func test_current_reflectsProviderStates() {
        let provider = FakePermissionsProvider([
            .microphone: .granted,
            .accessibility: .denied,
            .inputMonitoring: .notDetermined,
        ])
        let service = PermissionsService(provider: provider)

        let status = service.current()
        XCTAssertEqual(status.microphone, .granted)
        XCTAssertEqual(status.accessibility, .denied)
        XCTAssertEqual(status.inputMonitoring, .notDetermined)
    }

    func test_allGranted_trueWhenAllPermitted() {
        let provider = FakePermissionsProvider([
            .microphone: .granted,
            .accessibility: .granted,
            .inputMonitoring: .granted,
        ])
        let service = PermissionsService(provider: provider)
        XCTAssertTrue(service.current().allGranted)
    }

    func test_allGranted_falseWhenOneDenied() {
        let provider = FakePermissionsProvider([
            .microphone: .granted,
            .accessibility: .denied,
            .inputMonitoring: .granted,
        ])
        let service = PermissionsService(provider: provider)
        XCTAssertFalse(service.current().allGranted)
    }

    func test_firstMissing_returnsMicrophoneFirst() {
        let provider = FakePermissionsProvider([
            .microphone: .notDetermined,
            .accessibility: .denied,
            .inputMonitoring: .denied,
        ])
        let service = PermissionsService(provider: provider)
        XCTAssertEqual(service.current().firstMissing, .microphone)
    }

    func test_firstMissing_skipsGrantedAndReturnsNext() {
        let provider = FakePermissionsProvider([
            .microphone: .granted,
            .accessibility: .denied,
            .inputMonitoring: .denied,
        ])
        let service = PermissionsService(provider: provider)
        XCTAssertEqual(service.current().firstMissing, .accessibility)
    }

    func test_firstMissing_nilWhenAllGranted() {
        let provider = FakePermissionsProvider([
            .microphone: .granted,
            .accessibility: .granted,
            .inputMonitoring: .granted,
        ])
        let service = PermissionsService(provider: provider)
        XCTAssertNil(service.current().firstMissing)
    }

    func test_request_updatesStatusAndFiresCallback() {
        let provider = FakePermissionsProvider()
        let service = PermissionsService(provider: provider)

        // Use a lock-backed box to satisfy Swift 6 Sendable closure rules.
        final class Box<T: Sendable>: @unchecked Sendable {
            private let lock = NSLock()
            private var _value: T?
            var value: T? { lock.withLock { _value } }
            func set(_ v: T?) { lock.withLock { _value = v } }
        }

        let receivedState = Box<PermissionState>()
        let receivedStatus = Box<PermissionsStatus>()
        service.statusDidChange = { receivedStatus.set($0) }

        service.request(.microphone) { state in
            receivedState.set(state)
        }

        XCTAssertEqual(receivedState.value, .granted, "Callback must deliver the new state")
        XCTAssertEqual(service.current().microphone, .granted, "Service snapshot must reflect the grant")
        XCTAssertNotNil(receivedStatus.value, "statusDidChange must fire after a request")
        XCTAssertEqual(receivedStatus.value?.microphone, .granted)
    }

    func test_refresh_firesStatusDidChangeOnlyWhenSomethingChanged() {
        let provider = FakePermissionsProvider([.microphone: .granted])
        let service = PermissionsService(provider: provider)

        final class Counter: @unchecked Sendable {
            private let lock = NSLock()
            private var _n = 0
            var n: Int { lock.withLock { _n } }
            func increment() { lock.withLock { _n += 1 } }
        }
        let counter = Counter()
        service.statusDidChange = { _ in counter.increment() }

        // No change — provider still returns same values.
        service.refresh()
        XCTAssertEqual(counter.n, 0, "refresh without change must not fire statusDidChange")

        // Now simulate a revocation.
        provider.set(.microphone, to: .denied)
        service.refresh()
        XCTAssertEqual(counter.n, 1, "refresh after revocation must fire statusDidChange once")
        XCTAssertEqual(service.current().microphone, .denied)
    }
}
