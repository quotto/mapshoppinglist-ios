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
        XCTAssertEqual(viewModel.placeRows.count, 2)
        XCTAssertEqual(viewModel.placeRows.first?.title, "スーパーA")
        XCTAssertEqual(viewModel.placeRows.first?.detail, "東京都")
        XCTAssertEqual(viewModel.placeRows.last?.detail, nil)
        XCTAssertTrue(viewModel.selectedIds.contains(placeB.id))

        viewModel.toggle(placeId: placeA.id)
        XCTAssertTrue(viewModel.selectedIds.contains(placeA.id))

        viewModel.toggle(placeId: placeB.id)
        XCTAssertFalse(viewModel.selectedIds.contains(placeB.id))
    }

    func testPlaceRowTitleFallbackWhenNameMissing() {
        let place = Place(id: UUID(), name: "  ", latitudeE6: 0, longitudeE6: 0, note: "東京都千代田区", lastUsedAt: nil, isActive: true)
        let row = RecentPlacesPickerViewModel.PlaceRow(place: place)
        XCTAssertEqual(row.title, "東京都千代田区")
        XCTAssertNil(row.detail)

        let placeNoInfo = Place(id: UUID(), name: "", latitudeE6: 0, longitudeE6: 0, note: nil, lastUsedAt: nil, isActive: true)
        let rowNoInfo = RecentPlacesPickerViewModel.PlaceRow(place: placeNoInfo)
        XCTAssertEqual(rowNoInfo.title, "名称未設定")
        XCTAssertNil(rowNoInfo.detail)
    }
}
