import FoundationModels
import MapKit

@available(iOS 26, *)
final class GetTravelTimeTool: Tool {
    typealias Output = String

    let name = "getTravelTime"
    let description = "Get estimated travel time from the user's location to a destination. Use when they ask how long it takes to get somewhere."

    @Generable
    struct Arguments {
        @Guide(description: "Address or place name, e.g. 'SFO Airport' or '1 Infinite Loop, Cupertino'.")
        var destination: String

        @Guide(description: "Mode of transport: 'driving', 'walking', or 'transit'.")
        var transportType: String
    }

    func call(arguments: Arguments) async throws -> String {
        let origin = try await LocationManager.shared.currentLocation()

        guard let geoRequest = MKGeocodingRequest(addressString: arguments.destination) else {
            return "Couldn't build a geocoding request for '\(arguments.destination)'."
        }
        let mapItems = try await geoRequest.mapItems
        guard let dest = mapItems.first?.location else {
            return "Could not find '\(arguments.destination)'. Try a more specific address."
        }

        let transport: MKDirectionsTransportType = {
            switch arguments.transportType.lowercased() {
            case "walking": return .walking
            case "transit": return .transit
            default:        return .automobile
            }
        }()

        let request         = MKDirections.Request()
        request.source      = MKMapItem(placemark: MKPlacemark(coordinate: origin.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: dest.coordinate))
        request.transportType = transport

        let eta     = try await MKDirections(request: request).calculateETA()
        let minutes = Int(eta.expectedTravelTime / 60)
        let miles   = String(format: "%.1f mi", eta.distance / 1609.34)

        return "\(arguments.destination) is \(miles) away — about \(minutes) min by \(arguments.transportType.lowercased())."
    }
}
