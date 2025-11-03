import CoreLocation

@MainActor
protocol LocationPermissionManager: AnyObject {
    func authorizationStatus() -> CLAuthorizationStatus
    func requestAuthorization() async -> CLAuthorizationStatus
}

@MainActor
final class DefaultLocationPermissionManager: NSObject, CLLocationManagerDelegate, LocationPermissionManager {
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

    func requestAuthorization() async -> CLAuthorizationStatus {
        let status = manager.authorizationStatus
        // 標準のリクエスト要求ダイアログはステータスが.notDeterminedの場合にのみ表示されるため、
        // それ以外の場合は現在のステータスをそのまま返す
        switch status {
        case .notDetermined:
            return await requestWhenInUse()
        default:
            return status
        }
    }

    private func requestWhenInUse() async -> CLAuthorizationStatus {
        if continuation != nil { return manager.authorizationStatus }
        return await withCheckedContinuation { (continuation: CheckedContinuation<CLAuthorizationStatus, Never>) in
            self.continuation = continuation
            self.manager.requestWhenInUseAuthorization()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(returning: manager.authorizationStatus)
    }
}

private extension DefaultLocationPermissionManager {
    static var supportsBackgroundLocation: Bool {
        guard let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] else { return false }
        return modes.contains("location")
    }
}
