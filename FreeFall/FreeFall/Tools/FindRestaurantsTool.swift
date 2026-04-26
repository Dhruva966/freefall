import FoundationModels
import MapKit

@available(iOS 26, *)
final class FindRestaurantsTool: Tool {
    typealias Output = String

    let name = "findRestaurants"
    let description = "Find restaurants near the user. Use when they ask for food recommendations or what's nearby to eat."

    struct Arguments: Generable {
        let query: String
        let maxResults: Int
        let dietaryPreference: String
        let maxPriceLevel: Int

        static var generationSchema: GenerationSchema {
            GenerationSchema(
                type: Self.self,
                description: "Arguments for finding nearby restaurants.",
                properties: [
                    .init(name: "query",             description: "Cuisine or dish, e.g. 'sushi', 'pizza', 'tacos'.", type: String.self),
                    .init(name: "maxResults",        description: "Maximum number of results to return (1–10).", type: Int.self),
                    .init(name: "dietaryPreference", description: "Dietary filter: 'vegetarian', 'vegan', or 'none'.", type: String.self),
                    .init(name: "maxPriceLevel",     description: "Max price level 1 (cheap) to 4 (expensive). Use 0 for any.", type: Int.self)
                ]
            )
        }

        init(query: String, maxResults: Int, dietaryPreference: String, maxPriceLevel: Int) {
            self.query             = query
            self.maxResults        = maxResults
            self.dietaryPreference = dietaryPreference
            self.maxPriceLevel     = maxPriceLevel
        }

        init(_ content: GeneratedContent) throws {
            self.query             = try content.value(forProperty: "query")
            self.maxResults        = try content.value(forProperty: "maxResults")
            self.dietaryPreference = try content.value(forProperty: "dietaryPreference")
            self.maxPriceLevel     = try content.value(forProperty: "maxPriceLevel")
        }

        var generatedContent: GeneratedContent {
            GeneratedContent(properties: [
                "query": query,
                "maxResults": maxResults,
                "dietaryPreference": dietaryPreference,
                "maxPriceLevel": maxPriceLevel
            ])
        }
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
