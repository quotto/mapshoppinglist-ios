import Foundation

/// ジオフェンス登録差分を計算するユースケース。
public struct BuildGeofenceSyncPlanUseCase {
    private let registryRepository: GeofenceRegistryRepository

    public init(registryRepository: GeofenceRegistryRepository) {
        self.registryRepository = registryRepository
    }

    public func execute(activePlaces: [Place]) async throws -> GeofenceSyncPlan {
        let prioritized = activePlaces
            .sorted { (lhs, rhs) in
                switch (lhs.lastUsedAt, rhs.lastUsedAt) {
                case let (l?, r?): return l > r
                case (.some, .none): return true
                case (.none, .some): return false
                default: return lhs.name < rhs.name
                }
            }
            .prefix(DomainConstants.geofenceMonitorLimit)

        let targetSpecs = prioritized.map { place in
            GeofenceSpec(
                id: "place_\(place.id.uuidString)",
                placeId: place.id,
                latitudeE6: place.latitudeE6,
                longitudeE6: place.longitudeE6,
                radius: DomainConstants.geofenceRadius
            )
        }

        let current = try await registryRepository.fetchRegisteredGeofences()
        let targetIds = Set(targetSpecs.map { $0.id })
        let currentIds = Set(current.map { $0.id })

        let toRegisterIds = targetIds.subtracting(currentIds)
        let toUnregisterIds = currentIds.subtracting(targetIds)
        let toRegister = targetSpecs.filter { toRegisterIds.contains($0.id) }
        let toUnregister = current.filter { toUnregisterIds.contains($0.id) }

        return GeofenceSyncPlan(toRegister: toRegister, toUnregister: toUnregister)
    }
}
