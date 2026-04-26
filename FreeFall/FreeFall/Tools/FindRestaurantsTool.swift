import FoundationModels
import MapKit

@available(iOS 26, *)
final class FindRestaurantsTool: Tool {
    typealias Output = String

    let name = "findRestaurants"
    let description = "Find restaurants near the user. Use when they ask for food recommendations or what's nearby to eat."

    @Generable
    struct Arguments {
        @Guide(description: "Cuisine or dish, e.g. 'sushi', 'pizza', 'tacos'.")
        var query: String

        @Guide(description: "Maximum number of results to return (1–10).")
        var maxResults: Int

        @Guide(description: "Dietary filter: 'vegetarian', 'vegan', or 'none'.")
        var dietaryPreference: String

        @Guide(description: "Max price level 1 (cheap) to 4 (expensive). Use 0 for any.")
        var maxPriceLevel: Int
    }

    func call(arguments: Arguments) async throws -> String {
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

        guard !items.isEmpty else {
            return "No restaurants found nearby for '\(searchQuery)'."
        }

        let lines = items.map { item -> String in
            let name    = item.name ?? "Unknown"
            let address = [item.placemark.thoroughfare, item.placemark.locality]
                .compactMap { $0 }.joined(separator: ", ")
            let phone   = item.phoneNumber.map { " · \($0)" } ?? ""
            return "• \(name) — \(address)\(phone)"
        }

        return "Restaurants near you:\n" + lines.joined(separator: "\n")
    }
}
