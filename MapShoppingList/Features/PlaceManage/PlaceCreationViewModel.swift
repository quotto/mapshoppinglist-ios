import Foundation
import Combine

@MainActor
final class PlaceCreationViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var latitudeText: String = ""
    @Published var longitudeText: String = ""
    @Published var note: String = ""
    @Published var isSaving = false
    @Published var errorMessage: String?

    private let createPlaceUseCase: CreatePlaceUseCase

    init(createPlaceUseCase: CreatePlaceUseCase) {
        self.createPlaceUseCase = createPlaceUseCase
    }

    convenience init(environment: AppEnvironment) {
        self.init(createPlaceUseCase: environment.createPlaceUseCase)
    }

    func createPlace() async -> Bool {
        guard validateFields() else { return false }
        guard let latitudeE6 = toE6(latitudeText), let longitudeE6 = toE6(longitudeText) else {
            errorMessage = "緯度経度の形式が正しくありません"
            return false
        }
        isSaving = true
        errorMessage = nil
        let place = Place(
            id: UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            latitudeE6: latitudeE6,
            longitudeE6: longitudeE6,
            note: note.isEmpty ? nil : note,
            lastUsedAt: Date(),
            isActive: false
        )
        do {
            try await createPlaceUseCase.execute(place: place)
            isSaving = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
            return false
        }
    }

    private func validateFields() -> Bool {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "名称を入力してください"
            return false
        }
        if latitudeText.isEmpty || longitudeText.isEmpty {
            errorMessage = "緯度・経度を入力してください"
            return false
        }
        return true
    }

    private func toE6(_ text: String) -> Int? {
        guard let value = Double(text.replacingOccurrences(of: ",", with: ".")) else { return nil }
        return Int((value * 1_000_000).rounded())
    }
}
