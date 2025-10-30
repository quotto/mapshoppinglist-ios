import Foundation

/// 買い物地点のドメインモデル。
public struct Place: Equatable, Identifiable {
    public let id: UUID
    public var name: String
    public var latitudeE6: Int
    public var longitudeE6: Int
    public var note: String?
    public var lastUsedAt: Date?
    public var isActive: Bool

    public init(
        id: UUID,
        name: String,
        latitudeE6: Int,
        longitudeE6: Int,
        note: String? = nil,
        lastUsedAt: Date? = nil,
        isActive: Bool
    ) {
        self.id = id
        self.name = name
        self.latitudeE6 = latitudeE6
        self.longitudeE6 = longitudeE6
        self.note = note
        self.lastUsedAt = lastUsedAt
        self.isActive = isActive
    }
}
