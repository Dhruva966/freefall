import FoundationModels
import UIKit

// DoorDash has no public consumer ordering API. This tool deep-links into the
// DoorDash app (or web) so the user can review and confirm the order themselves.
// The LLM decides which restaurant to open; the human confirms the cart.
@available(iOS 26, *)
final class PlaceFoodOrderTool: Tool {
    typealias Output = String

    let name = "placeFoodOrder"
    let description = """
        Opens DoorDash to place a food order from a specific restaurant. Use this when \
        the user wants to order food for delivery. The user will confirm the order in the app.
        """

    @Generable
    struct Arguments {
        @Guide(description: "Name of the restaurant to order from.")
        var restaurantName: String

        @Guide(description: "Comma-separated list of items the user wants to order.")
        var items: String
    }

    func call(arguments: Arguments) async throws -> String {
        let encoded = arguments.restaurantName
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        let appURL  = URL(string: "doordash://search?q=\(encoded)")!
        let webURL  = URL(string: "https://www.doordash.com/search/\(encoded)")!

        await MainActor.run {
            if UIApplication.shared.canOpenURL(appURL) {
                UIApplication.shared.open(appURL)
            } else {
                UIApplication.shared.open(webURL)
            }
        }

        let itemSummary = arguments.items.isEmpty ? "" : " (\(arguments.items))"
        return (
            "Opened DoorDash for \(arguments.restaurantName)\(itemSummary). " +
            "Review your cart and tap Place Order to confirm."
        )
    }
}
