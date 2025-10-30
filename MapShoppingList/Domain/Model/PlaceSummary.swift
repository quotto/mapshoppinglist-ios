import Foundation

/// 一覧表示向けの地点情報。
public struct PlaceSummary: Equatable, Identifiable {
    public let id: UUID
    public var name: String
    public var isActive: Bool
    public var linkedItemCount: Int
    public var lastUsedAt: Date?

    public init(id: UUID, name: String, isActive: Bool, linkedItemCount: Int, lastUsedAt: Date?) {
        self.id = id
        self.name = name
        self.isActive = isActive
        self.linkedItemCount = linkedItemCount
        self.lastUsedAt = lastUsedAt
    }
}
