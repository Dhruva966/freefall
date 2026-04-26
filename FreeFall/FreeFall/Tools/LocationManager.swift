import CoreLocation
import Foundation

// Async wrapper around CLLocationManager used by all location-dependent tools.
// One shared instance; requestLocation() fires a one-shot fix each call.
final class LocationManager: NSObject, CLLocationManagerDelegate, @unchecked Sendable {
    static let shared = LocationManager()

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func currentLocation() async throws -> CLLocation {
        return try await withCheckedThrowingContinuation { cont in
            continuation = cont
            switch manager.authorizationStatus {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .denied, .restricted:
                cont.resume(throwing: LocationError.permissionDenied)
                continuation = nil
                return
            default:
                break
            }
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.first else { return }
        continuation?.resume(returning: loc)
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard manager.authorizationStatus != .notDetermined else { return }
        manager.requestLocation()
    }
}

enum LocationError: LocalizedError {
    case permissionDenied
    var errorDescription: String? {
        "Location access denied. Enable it in Settings → Privacy → Location Services."
    }
}
