import Foundation

/// 地点データへのアクセスを担う。
public protocol PlacesRepository {
    func fetchAllPlaces() async throws -> [Place]
    func fetchPlace(id: UUID) async throws -> Place?
    func fetchRecentPlaces(limit: Int) async throws -> [Place]
    func findPlace(latitudeE6: Int, longitudeE6: Int) async throws -> Place?
    func createPlace(_ place: Place) async throws
    func updatePlace(_ place: Place) async throws
    func deletePlace(id: UUID) async throws
    func countPlaces() async throws -> Int
}
