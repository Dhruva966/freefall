import Foundation
import FoundationModels
import UIKit

// Uses DuckDuckGo Instant Answer API — no key required.
// Returns text results directly to the LLM so it can reason over them.
// Falls back to opening the browser if no instant answer is available.
@available(iOS 26, *)
final class InternetSearchTool: Tool {
    typealias Output = String

    let name = "internetSearch"
    let description = "Search the internet and return results. Use for current events, facts, or anything the on-device model may not know."

    @Generable
    struct Arguments {
        @Guide(description: "The search query, e.g. 'best sushi in San Jose' or 'Tesla stock price'.")
        var query: String
    }

    private struct DDGResponse: Decodable {
        let AbstractText: String
        let AbstractSource: String
        let RelatedTopics: [RelatedTopic]
        struct RelatedTopic: Decodable { let Text: String? }
    }

    func call(arguments: Arguments) async throws -> String {
        let encoded = arguments.query
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let url = URL(string: "https://api.duckduckgo.com/?q=\(encoded)&format=json&no_html=1&skip_disambig=1")!

        let (data, _) = try await URLSession.shared.data(from: url)

        if let result = try? JSONDecoder().decode(DDGResponse.self, from: data) {
            var parts: [String] = []
            if !result.AbstractText.isEmpty {
                let src = result.AbstractSource.isEmpty ? "" : " (via \(result.AbstractSource))"
                parts.append(result.AbstractText + src)
            }
            result.RelatedTopics.compactMap(\.Text).filter { !$0.isEmpty }.prefix(3)
                .forEach { parts.append("• \($0)") }
            if !parts.isEmpty { return parts.joined(separator: "\n") }
        }

        // No instant answer — open browser
        let safariURL = URL(string: "https://www.google.com/search?q=\(encoded)")!
        let chromeURL = URL(string: "googlechrome://www.google.com/search?q=\(encoded)")!
        await MainActor.run {
            UIApplication.shared.open(
                UIApplication.shared.canOpenURL(chromeURL) ? chromeURL : safariURL
            )
        }
        return "No instant answer for '\(arguments.query)' — opened search results in your browser."
    }
}
