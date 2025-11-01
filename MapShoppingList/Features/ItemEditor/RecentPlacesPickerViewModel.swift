import Foundation
import Combine

@MainActor
final class RecentPlacesPickerViewModel: ObservableObject {
    @Published var places: [Place] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedIds: Set<UUID>

    private let getRecentPlacesUseCase: GetRecentPlacesUseCase
    private let loadLimit: Int

    init(getRecentPlacesUseCase: GetRecentPlacesUseCase, initialSelection: Set<UUID>, loadLimit: Int = 20) {
        self.getRecentPlacesUseCase = getRecentPlacesUseCase
        self.selectedIds = initialSelection
        self.loadLimit = loadLimit
    }

    convenience init(environment: AppEnvironment, initialSelection: Set<UUID>, loadLimit: Int = 20) {
        self.init(
            getRecentPlacesUseCase: environment.getRecentPlacesUseCase,
            initialSelection: initialSelection,
            loadLimit: loadLimit
        )
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            places = try await getRecentPlacesUseCase.execute(limit: loadLimit)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func toggle(place: Place) {
        if selectedIds.contains(place.id) {
            selectedIds.remove(place.id)
        } else {
            selectedIds.insert(place.id)
        }
    }
}
