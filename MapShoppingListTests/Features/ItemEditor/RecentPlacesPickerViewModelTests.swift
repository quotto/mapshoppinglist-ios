import Testing
import Foundation
@testable import MapShoppingList

@Suite("RecentPlacesPickerViewModelTests")
@MainActor
struct RecentPlacesPickerViewModelTests {
    @Test("load rows and toggle selections")
    func loadAndToggleSelection() async throws {
        let repository = InMemoryPlacesRepository()
        let now = Date()
        let placeA = Place(id: UUID(), name: "スーパーA", latitudeE6: 100, longitudeE6: 200, note: "東京都", lastUsedAt: now, isActive: true)
        let placeB = Place(id: UUID(), name: "コンビニB", latitudeE6: 300, longitudeE6: 400, note: nil, lastUsedAt: now.addingTimeInterval(-60), isActive: false)
        try await repository.createPlace(placeA)
        try await repository.createPlace(placeB)

        let viewModel = RecentPlacesPickerViewModel(
            getRecentPlacesUseCase: GetRecentPlacesUseCase(placesRepository: repository),
            initialSelection: [placeB.id]
        )

        await viewModel.load()
        #expect(viewModel.placeRows.count == 2)
        #expect(viewModel.placeRows.first?.title == "スーパーA")
        #expect(viewModel.placeRows.first?.detail == "東京都")
        #expect(viewModel.placeRows.last?.detail == nil)
        #expect(viewModel.selectedIds.contains(placeB.id))

        viewModel.toggle(placeId: placeA.id)
        #expect(viewModel.selectedIds.contains(placeA.id))

        viewModel.toggle(placeId: placeB.id)
        #expect(viewModel.selectedIds.contains(placeB.id) == false)
    }

    @Test("PlaceRow title fallback when name missing")
    func placeRowTitleFallbackWhenNameMissing() {
        let place = Place(id: UUID(), name: "  ", latitudeE6: 0, longitudeE6: 0, note: "東京都千代田区", lastUsedAt: nil, isActive: true)
        let row = RecentPlacesPickerViewModel.PlaceRow(place: place)
        #expect(row.title == "東京都千代田区")
        #expect(row.detail == nil)

        let placeNoInfo = Place(id: UUID(), name: "", latitudeE6: 0, longitudeE6: 0, note: nil, lastUsedAt: nil, isActive: true)
        let rowNoInfo = RecentPlacesPickerViewModel.PlaceRow(place: placeNoInfo)
        #expect(rowNoInfo.title == "名称未設定")
        #expect(rowNoInfo.detail == nil)
    }
}
