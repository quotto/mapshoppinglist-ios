import CoreLocation

@MainActor
protocol LocationPermissionManaging: AnyObject {
    func authorizationStatus() -> CLAuthorizationStatus
    func requestAlwaysAuthorizationIfNeeded() async -> CLAuthorizationStatus
}

@MainActor
final class LocationPermissionManager: NSObject, CLLocationManagerDelegate, LocationPermissionManaging {
    private let manager: CLLocationManager
    private var continuation: CheckedContinuation<CLAuthorizationStatus, Never>?

    override init() {
        manager = CLLocationManager()
        super.init()
        manager.delegate = self
        if Self.supportsBackgroundLocation {
            manager.allowsBackgroundLocationUpdates = true
        }
    }

    func authorizationStatus() -> CLAuthorizationStatus {
        manager.authorizationStatus
    }

    func requestAlwaysAuthorizationIfNeeded() async -> CLAuthorizationStatus {
        let status = manager.authorizationStatus
        switch status {
        case .notDetermined:
            return await requestAlways()
        case .authorizedWhenInUse:
            return await requestAlways()
        default:
            return status
        }
    }

    private func requestAlways() async -> CLAuthorizationStatus {
        if continuation != nil { return manager.authorizationStatus }
        return await withCheckedContinuation { (continuation: CheckedContinuation<CLAuthorizationStatus, Never>) in
            self.continuation = continuation
            self.manager.requestAlwaysAuthorization()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(returning: manager.authorizationStatus)
    }
}

private extension LocationPermissionManager {
    static var supportsBackgroundLocation: Bool {
        guard let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] else { return false }
        return modes.contains("location")
    }
}
