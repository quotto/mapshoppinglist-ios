import Foundation
import Combine

@MainActor
final class RecentPlacesPickerViewModel: ObservableObject {
    @Published var placeRows: [PlaceRow] = []
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
            let places = try await getRecentPlacesUseCase.execute(limit: loadLimit)
            placeRows = places.map { PlaceRow(place: $0) }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func toggle(placeId: UUID) {
        if selectedIds.contains(placeId) {
            selectedIds.remove(placeId)
        } else {
            selectedIds.insert(placeId)
        }
    }

    struct PlaceRow: Identifiable {
        let id: UUID
        let title: String
        let detail: String?

        init(place: Place) {
            id = place.id
            let trimmedName = place.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedNote = place.note?.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmedName.isEmpty {
                if let note = trimmedNote, note.isEmpty == false {
                    title = note
                    detail = nil
                } else {
                    title = "名称未設定"
                    detail = nil
                }
            } else {
                title = trimmedName
                if let note = trimmedNote, note.isEmpty == false, note != trimmedName {
                    detail = note
                } else {
                    detail = nil
                }
            }
        }
    }
}
