import Foundation

/// 買い物アイテムのドメインモデル。
public struct ShoppingItem: Equatable, Identifiable {
    public let id: UUID
    public var title: String
    public var note: String?
    public var isPurchased: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var placeIds: Set<UUID>

    public init(
        id: UUID,
        title: String,
        note: String? = nil,
        isPurchased: Bool,
        createdAt: Date,
        updatedAt: Date,
        placeIds: Set<UUID>
    ) {
        self.id = id
        self.title = title
        self.note = note
        self.isPurchased = isPurchased
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.placeIds = placeIds
    }
}
