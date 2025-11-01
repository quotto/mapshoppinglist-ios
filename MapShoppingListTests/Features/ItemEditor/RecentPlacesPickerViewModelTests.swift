import XCTest
@testable import MapShoppingList

@MainActor
final class RecentPlacesPickerViewModelTests: XCTestCase {
    func testLoadAndToggleSelection() async throws {
        let repository = InMemoryPlacesRepository()
        let now = Date()
        let placeA = Place(id: UUID(), name: "スーパーA", latitudeE6: 100, longitudeE6: 200, note: "東京都", lastUsedAt: now, isActive: true)
        let placeB = Place(id: UUID(), name: "コンビニB", latitudeE6: 300, longitudeE6: 400, note: nil, lastUsedAt: now.addingTimeInterval(-60), isActive: false)
        try await repository.createPlace(placeA)
        try await repository.createPlace(placeB)

        let viewModel = RecentPlacesPickerViewModel(getRecentPlacesUseCase: GetRecentPlacesUseCase(placesRepository: repository), initialSelection: [placeB.id])

        await viewModel.load()
        XCTAssertEqual(viewModel.places.count, 2)
        XCTAssertTrue(viewModel.selectedIds.contains(placeB.id))

        viewModel.toggle(place: placeA)
        XCTAssertTrue(viewModel.selectedIds.contains(placeA.id))

        viewModel.toggle(place: placeB)
        XCTAssertFalse(viewModel.selectedIds.contains(placeB.id))
    }
}
