import Foundation

/// 実装準備中のため、ジオフェンス登録を無効化したリポジトリ。
final class NoopGeofenceRegistryRepository: GeofenceRegistryRepository {
    var onRegionEntered: ((UUID) -> Void)?
    func fetchRegisteredGeofences() async throws -> [GeofenceSpec] { [] }
    func registerGeofences(_ geofences: [GeofenceSpec]) async throws { }
    func unregisterGeofences(_ geofences: [GeofenceSpec]) async throws { }
}
