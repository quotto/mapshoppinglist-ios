import Foundation
import Combine

@MainActor
final class ManualPlaceSelectionViewModel: ObservableObject {
    @Published var latitudeText: String = ""
    @Published var longitudeText: String = ""
    @Published var name: String = ""
    @Published var note: String = ""
    @Published var isGeocoding = false
    @Published var isSaving = false
    @Published var errorMessage: String?

    private let geocodingService: GeocodingService
    private let createPlaceUseCase: CreatePlaceUseCase

    init(geocodingService: GeocodingService, createPlaceUseCase: CreatePlaceUseCase) {
        self.geocodingService = geocodingService
        self.createPlaceUseCase = createPlaceUseCase
    }

    convenience init(environment: AppEnvironment) {
        self.init(geocodingService: environment.geocodingService, createPlaceUseCase: environment.createPlaceUseCase)
    }

    func updateCoordinate(latitude: Double, longitude: Double) {
        latitudeText = Self.formatCoordinate(latitude)
        longitudeText = Self.formatCoordinate(longitude)
        Task { await reverseGeocode(latitude: latitude, longitude: longitude) }
    }

    private func reverseGeocode(latitude: Double, longitude: Double) async {
        isGeocoding = true
        errorMessage = nil
        let result = await geocodingService.reverseGeocode(latitude: latitude, longitude: longitude)
        switch result {
        case let .success(geocode):
            if let primary = geocode.primaryText, primary.isEmpty == false {
                name = primary
            }
            if let secondary = geocode.secondaryText, secondary.isEmpty == false {
                note = secondary
            }
        case let .failure(error):
            errorMessage = error.localizedDescription
        }
        isGeocoding = false
    }

    func savePlace() async -> Place? {
        guard let latitude = Double(latitudeText.replacingOccurrences(of: ",", with: ".")),
              let longitude = Double(longitudeText.replacingOccurrences(of: ",", with: ".")) else {
            errorMessage = "緯度・経度を確認してください"
            return nil
        }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false else {
            errorMessage = "名称を入力してください"
            return nil
        }

        isSaving = true
        errorMessage = nil
        let place = Place(
            id: UUID(),
            name: trimmedName,
            latitudeE6: Int((latitude * 1_000_000).rounded()),
            longitudeE6: Int((longitude * 1_000_000).rounded()),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note,
            lastUsedAt: Date(),
            isActive: false
        )

        do {
            try await createPlaceUseCase.execute(place: place)
            isSaving = false
            return place
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
            return nil
        }
    }

    private static func formatCoordinate(_ value: Double) -> String {
        String(format: "%.6f", value)
    }
}
