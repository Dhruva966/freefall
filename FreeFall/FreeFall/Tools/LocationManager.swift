import CoreLocation
import Foundation

// CLLocationUpdate.liveUpdates() is CoreLocation's native async-sequence API
// (iOS 17+). It handles permission prompts internally, throws CLError.denied
// when the user refuses, and delivers updates on an actor-safe async stream.
// No delegate wiring, no continuation juggling, no main-thread guards needed.
@available(iOS 17, *)
final class LocationManager: Sendable {
    static let shared = LocationManager()
    private init() {}

    /// Returns the first valid location fix. Prompts for permission if needed.
    func currentLocation() async throws -> CLLocation {
        do {
            for try await update in CLLocationUpdate.liveUpdates() {
                if let loc = update.location { return loc }
            }
        } catch let clError as CLError where clError.code == .denied {
            throw LocationError.permissionDenied
        }
        throw LocationError.unavailable
    }
}

enum LocationError: LocalizedError {
    case permissionDenied
    case unavailable

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Location access denied. Enable it in Settings → Privacy → Location Services."
        case .unavailable:
            return "Could not determine your location. Try again in a moment."
        }
    }
}
