import FoundationModels
import UIKit

// DoorDash has no public consumer ordering API.
// This tool deep-links into the app so the user reviews and confirms the cart.
@available(iOS 26, *)
final class PlaceFoodOrderTool: Tool {
    typealias Output = String

    let name = "placeFoodOrder"
    let description = "Open DoorDash to order food from a restaurant. Use when the user wants delivery."

    @Generable
    struct Arguments {
        @Guide(description: "Name of the restaurant to order from.")
        var restaurantName: String

        @Guide(description: "Comma-separated items the user wants to order.")
        var items: String
    }

    func call(arguments: Arguments) async throws -> String {
        let encoded  = arguments.restaurantName
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let appURL   = URL(string: "doordash://search?q=\(encoded)")!
        let webURL   = URL(string: "https://www.doordash.com/search/\(encoded)")!

        await MainActor.run {
            UIApplication.shared.open(
                UIApplication.shared.canOpenURL(appURL) ? appURL : webURL
            )
        }

        let itemNote = arguments.items.isEmpty ? "" : " (\(arguments.items))"
        return "Opened DoorDash for \(arguments.restaurantName)\(itemNote). Review and confirm your cart in the app."
    }
}
