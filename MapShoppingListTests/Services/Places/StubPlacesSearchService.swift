import Foundation
import CoreLocation
@testable import MapShoppingList

final class StubPlacesSearchService: PlacesSearchService {
    var searchResult: Result<PlacesSearchResponse, Error>? {
        didSet { searchResultQueue.removeAll() }
    }
    var detailsResult: Result<PlaceDetails, Error>? {
        didSet { detailsResultsQueue.removeAll() }
    }
    private var searchResultQueue: [Result<PlacesSearchResponse, Error>] = []
    private var detailsResultsQueue: [Result<PlaceDetails, Error>] = []

    private(set) var receivedSessions: [PlacesSearchSession?] = []
    private(set) var receivedOrigins: [CLLocationCoordinate2D?] = []

    func enqueueSearchResult(_ result: Result<PlacesSearchResponse, Error>) {
        searchResultQueue.append(result)
    }

    func enqueueDetailsResult(_ result: Result<PlaceDetails, Error>) {
        detailsResultsQueue.append(result)
    }

    func search(
        query: String,
        session: PlacesSearchSession?,
        origin: CLLocationCoordinate2D?
    ) async throws -> PlacesSearchResponse {
        receivedSessions.append(session)
        receivedOrigins.append(origin)
        if searchResultQueue.isEmpty == false {
            let result = searchResultQueue.removeFirst()
            return try result.get()
        }
        guard let result = searchResult else {
            fatalError("autocompleteResult が設定されていません")
        }
        return try result.get()
    }

    func fetchPlaceDetails(placeId: String, session: PlacesSearchSession) async throws -> PlaceDetails {
        if detailsResultsQueue.isEmpty == false {
            let result = detailsResultsQueue.removeFirst()
            return try result.get()
        }
        guard let result = detailsResult else {
            fatalError("detailsResult が設定されていません")
        }
        return try result.get()
    }

    func fetchPlaceDetails(placeId: String) async throws -> PlaceDetails {
        if detailsResultsQueue.isEmpty == false {
            let result = detailsResultsQueue.removeFirst()
            return try result.get()
        }
        guard let result = detailsResult else {
            fatalError("detailsResult が設定されていません")
        }
        return try result.get()
    }
}
