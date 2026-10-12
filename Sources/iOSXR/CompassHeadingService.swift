import Combine
import CoreLocation
import Foundation

@MainActor
final class CompassHeadingService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var headingDegrees: CLLocationDirection?
    @Published private(set) var status = "Waiting for compass calibration"

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.headingFilter = 2
    }

    func start() {
        guard CLLocationManager.headingAvailable() else {
            status = "Compass is unavailable"
            return
        }

        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            beginHeadingUpdates()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            status = "Allow location access to calibrate north"
        @unknown default:
            status = "Compass authorization is unavailable"
        }
    }

    func stop() {
        manager.stopUpdatingHeading()
        manager.stopUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        start()
    }

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateHeading newHeading: CLHeading
    ) {
        guard newHeading.headingAccuracy >= 0 else {
            status = "Move away from magnetic interference"
            return
        }

        let heading = newHeading.trueHeading >= 0
            ? newHeading.trueHeading
            : newHeading.magneticHeading
        headingDegrees = heading
        status = newHeading.trueHeading >= 0
            ? "Calibrated to true north"
            : "Calibrated to magnetic north"
    }

    func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        status = "Compass unavailable: \(error.localizedDescription)"
    }

    private func beginHeadingUpdates() {
        manager.startUpdatingLocation()
        manager.startUpdatingHeading()
        status = "Calibrating compass"
    }
}
