import SwiftUI
import CoreLocation
import GoogleMaps

struct ManualPlacePickerMapView: UIViewRepresentable {
    final class Coordinator: NSObject, GMSMapViewDelegate {
        var parent: ManualPlacePickerMapView

        init(parent: ManualPlacePickerMapView) {
            self.parent = parent
        }

        func mapView(_ mapView: GMSMapView, didLongPressAt coordinate: CLLocationCoordinate2D) {
            parent.onCoordinateSelected(coordinate)
            parent.updateMarker(on: mapView, coordinate: coordinate)
        }
    }

    let initialCoordinate: CLLocationCoordinate2D
    let selectedCoordinate: CLLocationCoordinate2D?
    let onCoordinateSelected: (CLLocationCoordinate2D) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> GMSMapView {
        let mapView = GMSMapView(frame: .zero, camera: GMSCameraPosition(latitude: initialCoordinate.latitude, longitude: initialCoordinate.longitude, zoom: 14))
        mapView.delegate = context.coordinator
        mapView.settings.myLocationButton = true
        mapView.isMyLocationEnabled = false
        if let selected = selectedCoordinate {
            updateMarker(on: mapView, coordinate: selected)
        }
        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        if let selected = selectedCoordinate {
            mapView.animate(toLocation: selected)
            updateMarker(on: mapView, coordinate: selected)
        }
    }

    fileprivate func updateMarker(on mapView: GMSMapView, coordinate: CLLocationCoordinate2D) {
        mapView.clear()
        let marker = GMSMarker(position: coordinate)
        marker.map = mapView

        let circle = GMSCircle(position: coordinate, radius: 100)
        circle.fillColor = UIColor.systemBlue.withAlphaComponent(0.1)
        circle.strokeColor = UIColor.systemBlue
        circle.strokeWidth = 1
        circle.map = mapView
    }
}
