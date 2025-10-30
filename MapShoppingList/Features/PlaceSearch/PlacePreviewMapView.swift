import SwiftUI
import CoreLocation
import GoogleMaps
import UIKit

/// Google Maps を用いて地点プレビューを表示する SwiftUI ラッパー。
struct PlacePreviewMapView: UIViewRepresentable {
    let latitude: Double
    let longitude: Double

    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition.camera(withLatitude: latitude, longitude: longitude, zoom: 16)
        let mapView = GMSMapView(frame: .zero, camera: camera)
        mapView.settings.zoomGestures = true
        mapView.settings.rotateGestures = false
        updateOverlay(on: mapView)
        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        mapView.camera = GMSCameraPosition.camera(withLatitude: latitude, longitude: longitude, zoom: 16)
        updateOverlay(on: mapView)
    }

    private func updateOverlay(on mapView: GMSMapView) {
        mapView.clear()
        let position = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

        let marker = GMSMarker(position: position)
        marker.map = mapView

        let circle = GMSCircle(position: position, radius: 100)
        circle.fillColor = UIColor.systemBlue.withAlphaComponent(0.1)
        circle.strokeColor = UIColor.systemBlue
        circle.strokeWidth = 1
        circle.map = mapView
    }
}
