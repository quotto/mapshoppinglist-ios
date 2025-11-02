import CoreLocation
import Foundation

@MainActor
final class CoreLocationGeofenceRegistryRepository: NSObject, GeofenceRegistryRepository, CLLocationManagerDelegate {
    private let manager: CLLocationManager
    var onRegionEntered: ((UUID) -> Void)?

    override init() {
        manager = CLLocationManager()
        super.init()
        manager.delegate = self
        if Self.supportsBackgroundLocation {
            manager.allowsBackgroundLocationUpdates = true
            manager.pausesLocationUpdatesAutomatically = false
        }
    }

    func fetchRegisteredGeofences() async throws -> [GeofenceSpec] {
        manager.monitoredRegions.compactMap { region -> GeofenceSpec? in
            guard let circular = region as? CLCircularRegion else { return nil }
            guard let placeId = Self.placeId(from: circular.identifier) else { return nil }
            return GeofenceSpec(
                id: circular.identifier,
                placeId: placeId,
                latitudeE6: Int(circular.center.latitude * 1_000_000),
                longitudeE6: Int(circular.center.longitude * 1_000_000),
                radius: circular.radius
            )
        }
    }

    func registerGeofences(_ geofences: [GeofenceSpec]) async throws {
        for spec in geofences {
            let center = CLLocationCoordinate2D(
                latitude: Double(spec.latitudeE6) / 1_000_000,
                longitude: Double(spec.longitudeE6) / 1_000_000
            )
            let region = CLCircularRegion(center: center, radius: spec.radius, identifier: spec.id)
            region.notifyOnEntry = true
            region.notifyOnExit = false
            manager.startMonitoring(for: region)
            debugPrint("[Geofence] start monitoring id=\(spec.id) center=(\(center.latitude), \(center.longitude)) radius=\(spec.radius)")
        }
        logCurrentRegions(context: "register")
    }

    func unregisterGeofences(_ geofences: [GeofenceSpec]) async throws {
        for spec in geofences {
            if let region = manager.monitoredRegions.first(where: { $0.identifier == spec.id }) {
                debugPrint("[Geofence] stop monitoring id=\(spec.id)")
                manager.stopMonitoring(for: region)
            }
        }
        logCurrentRegions(context: "unregister")
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let placeId = Self.placeId(from: region.identifier) else { return }
        debugPrint("[Geofence] didEnterRegion repo=\(ObjectIdentifier(self)) manager=\(ObjectIdentifier(manager)) id=\(region.identifier) at \(Date())")
        onRegionEntered?(placeId)
    }

    private static func placeId(from identifier: String) -> UUID? {
        guard let uuidString = identifier.split(separator: "_").last else { return nil }
        return UUID(uuidString: String(uuidString))
    }
}

private extension CoreLocationGeofenceRegistryRepository {
    static var supportsBackgroundLocation: Bool {
        guard let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] else { return false }
        return modes.contains("location")
    }

    func logCurrentRegions(context: String) {
        let identifiers = manager.monitoredRegions.map { $0.identifier }
        debugPrint("[Geofence] monitoredRegions after \(context): \(identifiers)")
    }
}
