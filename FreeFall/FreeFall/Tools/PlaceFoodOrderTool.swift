import FoundationModels
import UIKit

// DoorDash has no public consumer ordering API.
// This tool deep-links into the app so the user reviews and confirms the cart.
@available(iOS 26, *)
final class PlaceFoodOrderTool: Tool {
    typealias Output = String

    let name = "placeFoodOrder"
    let description = "Open DoorDash to order food from a restaurant. Use when the user wants delivery."

    struct Arguments: Generable {
        let restaurantName: String
        let items: String

        static var generationSchema: GenerationSchema {
            GenerationSchema(
                type: Self.self,
                description: "Arguments for opening a food order.",
                properties: [
                    .init(name: "restaurantName", description: "Name of the restaurant to order from.", type: String.self),
                    .init(name: "items",          description: "Comma-separated items the user wants to order.", type: String.self)
                ]
            )
        }

        init(restaurantName: String, items: String) {
            self.restaurantName = restaurantName
            self.items          = items
        }

        init(_ content: GeneratedContent) throws {
            self.restaurantName = try content.value(forProperty: "restaurantName")
            self.items          = try content.value(forProperty: "items")
        }

        var generatedContent: GeneratedContent {
            GeneratedContent(properties: ["restaurantName": restaurantName, "items": items])
        }
    }

    func call(arguments: Arguments) async throws -> String {
        let encoded  = arguments.restaurantName
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let appURL   = URL(string: "doordash://search?q=\(encoded)")!
        let webURL   = URL(string: "https://www.doordash.com/search/\(encoded)")!

        await MainActor.run {
            if UIApplication.shared.canOpenURL(appURL) {
                UIApplication.shared.open(appURL)
            } else {
                UIApplication.shared.open(webURL)
            }
        }

        let itemNote = arguments.items.isEmpty ? "" : " (\(arguments.items))"
        return "Opened DoorDash for \(arguments.restaurantName)\(itemNote). Review and confirm your cart in the app."
    }
}
