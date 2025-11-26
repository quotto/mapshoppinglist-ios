import Foundation

struct AppSecrets: Decodable {
    struct GoogleMaps: Decodable {
        let apiKey: String?
    }

    let googleMaps: GoogleMaps?

    static func load() -> AppSecrets? {
        guard let url = Bundle.main.url(forResource: "AppSecrets", withExtension: "json") else {
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            guard data.isEmpty == false else { return nil }
            return try JSONDecoder().decode(AppSecrets.self, from: data)
        } catch {
            #if DEBUG
            print("[AppSecrets] Failed to decode AppSecrets.json: \(error)")
            #endif
            return nil
        }
    }
}
