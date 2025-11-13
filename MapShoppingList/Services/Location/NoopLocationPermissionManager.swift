import CoreLocation

/// テストやプレビュー用に位置情報権限の問い合わせ/リクエストを無効化する実装。
@MainActor
final class NoopLocationPermissionManager: LocationPermissionManager {
    private let status: CLAuthorizationStatus

    init(status: CLAuthorizationStatus = .authorizedAlways) {
        self.status = status
    }

    func authorizationStatus() -> CLAuthorizationStatus { status }

    func requestAuthorization() async -> CLAuthorizationStatus { status }
}
