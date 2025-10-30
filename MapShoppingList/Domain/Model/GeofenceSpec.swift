import Foundation

/// ジオフェンス登録に必要な情報。
public struct GeofenceSpec: Equatable, Identifiable {
    public let id: String
    public let placeId: UUID
    public let latitudeE6: Int
    public let longitudeE6: Int
    public let radius: Double

    public init(id: String, placeId: UUID, latitudeE6: Int, longitudeE6: Int, radius: Double) {
        self.id = id
        self.placeId = placeId
        self.latitudeE6 = latitudeE6
        self.longitudeE6 = longitudeE6
        self.radius = radius
    }
}

/// ジオフェンス同期の結果。
public struct GeofenceSyncPlan: Equatable {
    public let toRegister: [GeofenceSpec]
    public let toUnregister: [GeofenceSpec]

    public init(toRegister: [GeofenceSpec], toUnregister: [GeofenceSpec]) {
        self.toRegister = toRegister
        self.toUnregister = toUnregister
    }
}
