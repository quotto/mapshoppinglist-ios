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

@MainActor
protocol CurrentLocationProviding: AnyObject {
    func currentLocation() async throws -> CLLocationCoordinate2D
}

@MainActor
enum CurrentLocationError: Error {
    case unauthorized
    case busy
}

/// 端末の現在地を1回だけ取得するためのプロバイダ。
@MainActor
final class DefaultCurrentLocationProvider: NSObject, CLLocationManagerDelegate, CurrentLocationProviding {
    private let manager: CLLocationManager
    private var continuation: CheckedContinuation<CLLocationCoordinate2D, Error>?

    override init() {
        manager = CLLocationManager()
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func currentLocation() async throws -> CLLocationCoordinate2D {
        guard manager.authorizationStatus.isAuthorized else {
            throw CurrentLocationError.unauthorized
        }
        guard continuation == nil else { throw CurrentLocationError.busy }
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CLLocationCoordinate2D, Error>) in
            self.continuation = continuation
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let continuation else { return }
        self.continuation = nil
        if let coordinate = locations.first?.coordinate {
            continuation.resume(returning: coordinate)
        } else {
            continuation.resume(throwing: CurrentLocationError.unauthorized)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(throwing: error)
    }
}

/// 固定座標を返すテスト用プロバイダ。
@MainActor
final class FixedCurrentLocationProvider: CurrentLocationProviding {
    private let coordinate: CLLocationCoordinate2D

    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
    }

    func currentLocation() async throws -> CLLocationCoordinate2D { coordinate }
}

private extension CLAuthorizationStatus {
    var isAuthorized: Bool {
        switch self {
        case .authorizedAlways, .authorizedWhenInUse, .authorized:
            return true
        default:
            return false
        }
    }
}
