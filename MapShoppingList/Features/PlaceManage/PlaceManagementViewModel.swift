import Foundation
import Combine

@MainActor
final class PlaceManagementViewModel: ObservableObject {
    struct Row: Identifiable, Equatable {
        let id: UUID
        var name: String
        let isActive: Bool
        let lastUsedAt: Date?
        let address: String?
    }

    @Published var places: [Row] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var renamingPlace: Row?
    @Published var newName: String = ""

    private let loadPlacesUseCase: LoadAllPlacesUseCase
    private let updateNameUseCase: UpdatePlaceNameUseCase
    private let deletePlaceUseCase: DeletePlaceUseCase

    init(
        loadPlacesUseCase: LoadAllPlacesUseCase,
        updateNameUseCase: UpdatePlaceNameUseCase,
        deletePlaceUseCase: DeletePlaceUseCase
    ) {
        self.loadPlacesUseCase = loadPlacesUseCase
        self.updateNameUseCase = updateNameUseCase
        self.deletePlaceUseCase = deletePlaceUseCase
    }

    convenience init(environment: AppEnvironment) {
        self.init(
            loadPlacesUseCase: environment.loadAllPlacesUseCase,
            updateNameUseCase: environment.updatePlaceNameUseCase,
            deletePlaceUseCase: environment.deletePlaceUseCase
        )
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let domainPlaces = try await loadPlacesUseCase.execute()
            places = domainPlaces.map { place in
                Row(
                    id: place.id,
                    name: place.name,
                    isActive: place.isActive,
                    lastUsedAt: place.lastUsedAt,
                    address: place.note
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func beginRenaming(place: Row) {
        renamingPlace = place
        newName = place.name
    }

    func commitRename() async {
        guard let target = renamingPlace else { return }
        do {
            try await updateNameUseCase.execute(placeId: target.id, newName: newName)
            renamingPlace = nil
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(place: Row) async {
        do {
            try await deletePlaceUseCase.execute(placeId: place.id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
