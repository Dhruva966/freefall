import CoreLocation
import FoundationModels
import MapKit

@available(iOS 26, *)
final class GetTravelTimeTool: Tool {
    typealias Output = String

    let name = "getTravelTime"
    let description = "Get estimated travel time from the user's location to a destination. Use when they ask how long it takes to get somewhere."

    struct Arguments: Generable {
        let destination: String
        let transportType: String

        static var generationSchema: GenerationSchema {
            GenerationSchema(
                type: Self.self,
                description: "Arguments for estimating travel time.",
                properties: [
                    .init(name: "destination",   description: "Address or place name, e.g. 'SFO Airport' or '1 Infinite Loop, Cupertino'.", type: String.self),
                    .init(name: "transportType", description: "Mode of transport: 'driving', 'walking', or 'transit'.", type: String.self)
                ]
            )
        }

        init(destination: String, transportType: String) {
            self.destination   = destination
            self.transportType = transportType
        }

        init(_ content: GeneratedContent) throws {
            self.destination   = try content.value(forProperty: "destination")
            self.transportType = try content.value(forProperty: "transportType")
        }

        var generatedContent: GeneratedContent {
            GeneratedContent(properties: ["destination": destination, "transportType": transportType])
        }
    }

    func call(arguments: Arguments) async throws -> String {
        let origin = try await LocationManager.shared.currentLocation()

        let placemarks = try await CLGeocoder().geocodeAddressString(arguments.destination)
        guard let dest = placemarks.first?.location else {
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
