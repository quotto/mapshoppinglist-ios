import SwiftUI
import CoreLocation
import GoogleMaps

struct PlaceSearchMapView: UIViewRepresentable {
    final class Coordinator: NSObject, GMSMapViewDelegate {
        var parent: PlaceSearchMapView
        var lastMarkerCoordinate: CLLocationCoordinate2D?
        var lastInitialCenter: CLLocationCoordinate2D?

        init(parent: PlaceSearchMapView) {
            self.parent = parent
        }

        func mapView(_ mapView: GMSMapView, idleAt position: GMSCameraPosition) {
            parent.onCameraIdle(position.target)
        }

        func mapView(_ mapView: GMSMapView, didLongPressAt coordinate: CLLocationCoordinate2D) {
            parent.onCoordinateSelected(coordinate)
            parent.updateMarker(on: mapView, coordinate: coordinate)
        }

        func mapView(_ mapView: GMSMapView, didTapPOIWithPlaceID placeID: String, name: String, location: CLLocationCoordinate2D) {
            parent.onPOITapped(placeID, name, location)
            parent.updateMarker(on: mapView, coordinate: location)
        }
    }

    let initialCameraCoordinate: CLLocationCoordinate2D?
    let coordinate: CLLocationCoordinate2D?
    let onCoordinateSelected: (CLLocationCoordinate2D) -> Void
    let onPOITapped: (String, String, CLLocationCoordinate2D) -> Void
    let onCameraIdle: (CLLocationCoordinate2D) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> GMSMapView {
        let initial = initialCameraCoordinate ?? coordinate ?? PlaceSearchViewModel.fallbackCoordinate
        let mapView = GMSMapView(frame: .zero, camera: GMSCameraPosition(latitude: initial.latitude, longitude: initial.longitude, zoom: 14))
        mapView.delegate = context.coordinator
        mapView.settings.myLocationButton = false
        mapView.isMyLocationEnabled = false
        if let coord = coordinate {
            updateMarker(on: mapView, coordinate: coord)
        }
        context.coordinator.lastInitialCenter = initial
        // 初期表示時にも中心座標を通知して検索基点に利用できるようにする
        onCameraIdle(mapView.camera.target)
        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        if let coord = coordinate {
            // 選択座標が更新された時のみカメラ・マーカーを動かす
            if context.coordinator.lastMarkerCoordinate?.latitude != coord.latitude ||
                context.coordinator.lastMarkerCoordinate?.longitude != coord.longitude {
                mapView.animate(toLocation: coord)
                updateMarker(on: mapView, coordinate: coord)
                context.coordinator.lastMarkerCoordinate = coord
            }
            return
        }

        // 選択地点が無い場合は初期カメラ座標が更新された時のみ反映する。
        if let initialCameraCoordinate,
           (context.coordinator.lastInitialCenter?.latitude != initialCameraCoordinate.latitude ||
            context.coordinator.lastInitialCenter?.longitude != initialCameraCoordinate.longitude) {
            mapView.animate(toLocation: initialCameraCoordinate)
            context.coordinator.lastInitialCenter = initialCameraCoordinate
        }
    }

    fileprivate func updateMarker(on mapView: GMSMapView, coordinate: CLLocationCoordinate2D) {
        mapView.clear()
        let marker = GMSMarker(position: coordinate)
        marker.map = mapView

        let circle = GMSCircle(position: coordinate, radius: 100)
        circle.fillColor = UIColor.appPrimaryLight.withAlphaComponent(0.15)
        circle.strokeColor = UIColor.appPrimary
        circle.strokeWidth = 1.5
        circle.map = mapView
    }
}
