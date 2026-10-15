import Foundation
import CoreLocation
import UIKit

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var location: CLLocation?
    @Published var placemark: CLPlacemark?
    @Published var authStatus: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var lastGeocodedLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 3
        authStatus = manager.authorizationStatus
    }

    func start() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        manager.startUpdatingLocation()
    }

    var isDenied: Bool {
        authStatus == .denied || authStatus == .restricted
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authStatus = manager.authorizationStatus
        }
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }
        DispatchQueue.main.async {
            self.location = newLocation
            self.refreshMapIfNeeded(newLocation)
        }
        reverseGeocodeIfNeeded(newLocation)
    }

    // Hızlı çekim için harita görüntüsünü önceden hazırla
    @Published var mapImage: UIImage?
    private var lastMapLocation: CLLocation?
    private var mapLoading = false

    private func refreshMapIfNeeded(_ newLocation: CLLocation) {
        if mapLoading { return }
        if let last = lastMapLocation, newLocation.distance(from: last) < 40, mapImage != nil { return }
        mapLoading = true
        lastMapLocation = newLocation
        Stamper.mapSnapshot(for: newLocation.coordinate) { [weak self] img in
            guard let self = self else { return }
            self.mapLoading = false
            if let img = img { self.mapImage = img } else { self.lastMapLocation = nil }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Konum geçici olarak alınamazsa sessizce bekle
    }

    private func reverseGeocodeIfNeeded(_ newLocation: CLLocation) {
        if let last = lastGeocodedLocation, newLocation.distance(from: last) < 20, placemark != nil {
            return
        }
        if geocoder.isGeocoding { return }
        lastGeocodedLocation = newLocation
        geocoder.reverseGeocodeLocation(newLocation, preferredLocale: Locale(identifier: "tr_TR")) { [weak self] placemarks, _ in
            guard let self = self, let first = placemarks?.first else { return }
            DispatchQueue.main.async {
                self.placemark = first
            }
        }
    }
}
