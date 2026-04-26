import FoundationModels
import MapKit

@available(iOS 18.1, *)
final class FindRestaurantsTool: Tool {
    let name = "findRestaurants"
    let description = """
        Finds restaurants near the user's current location. Use this when the user asks \
        for food recommendations, what's nearby, or wants to eat out.
        """

    @Generable
    struct Arguments {
        @Guide(description: "Cuisine type or dish to search for, e.g. 'sushi', 'pizza', 'tacos'.")
        var query: String

        @Guide(description: "Maximum number of results to return.")
        var maxResults: Int

        @Guide(description: "Dietary filter: 'vegetarian', 'vegan', or 'none'.")
        var dietaryPreference: String

        @Guide(description: "Maximum price level 1 (cheap) to 4 (expensive). Use 0 for any price.")
        var maxPriceLevel: Int
    }

    func call(arguments: Arguments) async throws -> ToolOutput {
        let location = try await LocationManager.shared.currentLocation()

        let searchQuery = arguments.dietaryPreference == "none"
            ? arguments.query
            : "\(arguments.dietaryPreference) \(arguments.query)"

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchQuery
        request.resultTypes = .pointOfInterest
        request.region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: 3000,
            longitudinalMeters: 3000
        )

        let response = try await MKLocalSearch(request: request).start()
        let items = response.mapItems.prefix(max(1, arguments.maxResults))

        if items.isEmpty {
            return ToolOutput("No restaurants found nearby for '\(searchQuery)'.")
        }

        let lines = items.map { item -> String in
            let name    = item.name ?? "Unknown"
            let address = [
                item.placemark.thoroughfare,
                item.placemark.locality
            ].compactMap { $0 }.joined(separator: ", ")
            let phone   = item.phoneNumber.map { " · \($0)" } ?? ""
            return "• \(name) — \(address)\(phone)"
        }

        return ToolOutput("Restaurants near you:\n" + lines.joined(separator: "\n"))
    }
}
