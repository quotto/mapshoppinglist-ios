import Foundation

protocol NearbySuggestionStateRepository {
    func fetchState(forItem itemId: UUID) async throws -> NearbySuggestionState?
    func upsert(state: NearbySuggestionState) async throws
}
