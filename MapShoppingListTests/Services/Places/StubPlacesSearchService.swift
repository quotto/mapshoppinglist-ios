import Foundation
import CoreLocation
@testable import MapShoppingList

final class StubPlacesSearchService: PlacesSearchService {
    var searchResult: Result<PlacesSearchResponse, Error>? {
        didSet { searchResultQueue.removeAll() }
    }
    var nearbySearchResult: Result<PlacesSearchResponse, Error>? {
        didSet { nearbySearchResultQueue.removeAll() }
    }
    var detailsResult: Result<PlaceDetails, Error>? {
        didSet { detailsResultsQueue.removeAll() }
    }
    private var searchResultQueue: [Result<PlacesSearchResponse, Error>] = []
    private var nearbySearchResultQueue: [Result<PlacesSearchResponse, Error>] = []
    private var detailsResultsQueue: [Result<PlaceDetails, Error>] = []

    private(set) var receivedOptions: [PlacesSearchOptions] = []
    private(set) var receivedQueries: [String] = []
    private(set) var receivedSessions: [PlacesSearchSession?] = []
    private(set) var receivedOrigins: [CLLocationCoordinate2D?] = []
    private(set) var receivedNearbyTypes: [String] = []
    private(set) var receivedNearbyOptions: [PlacesSearchOptions] = []

    func enqueueSearchResult(_ result: Result<PlacesSearchResponse, Error>) {
        searchResultQueue.append(result)
    }

    func enqueueNearbySearchResult(_ result: Result<PlacesSearchResponse, Error>) {
        nearbySearchResultQueue.append(result)
    }

    func enqueueDetailsResult(_ result: Result<PlaceDetails, Error>) {
        detailsResultsQueue.append(result)
    }

    func search(query: String, options: PlacesSearchOptions) async throws -> PlacesSearchResponse {
        receivedQueries.append(query)
        receivedOptions.append(options)
        receivedSessions.append(options.session)
        receivedOrigins.append(options.origin)
        if searchResultQueue.isEmpty == false {
            let result = searchResultQueue.removeFirst()
            return try result.get()
        }
        guard let result = searchResult else {
            fatalError("searchResult が設定されていません")
        }
        return try result.get()
    }

    func searchNearby(includedType: String, options: PlacesSearchOptions) async throws -> PlacesSearchResponse {
        receivedNearbyTypes.append(includedType)
        receivedNearbyOptions.append(options)
        if nearbySearchResultQueue.isEmpty == false {
            let result = nearbySearchResultQueue.removeFirst()
            return try result.get()
        }
        guard let result = nearbySearchResult else {
            fatalError("nearbySearchResult が設定されていません")
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
