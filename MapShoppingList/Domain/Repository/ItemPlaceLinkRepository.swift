import Foundation

/// アイテムと地点の関連を管理する。
public protocol ItemPlaceLinkRepository {
    func fetchPlaceIds(forItem itemId: UUID) async throws -> Set<UUID>
    func link(itemId: UUID, placeId: UUID) async throws
    func unlink(itemId: UUID, placeId: UUID) async throws
}
