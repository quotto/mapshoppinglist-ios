import XCTest
@testable import MapShoppingList

/// PlaceManagementViewModel の名称変更フローに関するテスト。
@MainActor
final class PlaceManagementViewModelTests: XCTestCase {
    func test名称変更がシート閉じても反映される() async throws {
        // Arrange
        let placeId = UUID()
        let initial = Place(
            id: placeId,
            name: "テストスーパーA",
            latitudeE6: 0,
            longitudeE6: 0,
            note: nil,
            lastUsedAt: nil,
            isActive: true
        )
        let repo = InMemoryPlacesRepository()
        try await repo.createPlace(initial)
        let viewModel = PlaceManagementViewModel(
            loadPlacesUseCase: LoadAllPlacesUseCase(placesRepository: repo),
            updateNameUseCase: UpdatePlaceNameUseCase(placesRepository: repo),
            deletePlaceUseCase: DeletePlaceUseCase(placesRepository: repo)
        )

        await viewModel.load()
        guard let row = viewModel.places.first else {
            XCTFail("初期データの読み込みに失敗")
            return
        }

        // Act
        viewModel.beginRenaming(place: row)
        viewModel.newName = "テストスーパーA リニューアル"
        // シートの dismiss により renamingPlace が nil になるケースを再現
        viewModel.renamingPlace = nil
        await viewModel.commitRename(target: row)

        // Assert
        let stored = try await repo.fetchPlace(id: placeId)
        XCTAssertEqual(stored?.name, "テストスーパーA リニューアル")
        XCTAssertEqual(viewModel.places.first?.name, "テストスーパーA リニューアル")
    }
}
