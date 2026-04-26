import CoreLocation
import FoundationModels
import MapKit

@available(iOS 26, *)
final class GetTravelTimeTool: Tool {
    typealias Output = String

    let name = "getTravelTime"
    let description = """
        Returns estimated travel time and distance from the user's current location \
        to a destination. Use this when the user asks how long it takes to get somewhere, \
        or wants directions.
        """

    @Generable
    struct Arguments {
        @Guide(description: "Destination address or place name, e.g. '1 Infinite Loop, Cupertino' or 'SFO Airport'.")
        var destination: String

        @Guide(description: "Transport mode: 'driving', 'walking', or 'transit'.")
        var transportType: String
    }

    func call(arguments: Arguments) async throws -> String {
        let origin = try await LocationManager.shared.currentLocation()

        let placemarks = try await CLGeocoder().geocodeAddressString(arguments.destination)
        guard let dest = placemarks.first?.location else {
            return ("Could not find '\(arguments.destination)'. Try a more specific address.")
        }

        let transport: MKDirectionsTransportType = {
            switch arguments.transportType.lowercased() {
            case "walking": return .walking
            case "transit": return .transit
            default:        return .automobile
            }
        }()

        let request = MKDirections.Request()
        request.source      = MKMapItem(placemark: MKPlacemark(coordinate: origin.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: dest.coordinate))
        request.transportType = transport

        let eta = try await MKDirections(request: request).calculateETA()

        let minutes  = Int(eta.expectedTravelTime / 60)
        let miles    = eta.distance / 1609.34
        let distStr  = String(format: "%.1f mi", miles)
        let modeStr  = arguments.transportType.lowercased()

        return (
            "\(arguments.destination) is \(distStr) away — about \(minutes) min by \(modeStr)."
        )
    }
}
