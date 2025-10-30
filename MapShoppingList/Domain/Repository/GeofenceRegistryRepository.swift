import Foundation

/// 実際に登録済みのジオフェンス集合を扱う。
public protocol GeofenceRegistryRepository {
    func fetchRegisteredGeofences() async throws -> [GeofenceSpec]
    func registerGeofences(_ geofences: [GeofenceSpec]) async throws
    func unregisterGeofences(_ geofences: [GeofenceSpec]) async throws
}
