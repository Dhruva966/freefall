import Foundation
import FoundationModels
import UIKit

// Uses the DuckDuckGo Instant Answer API — no key required, runs a real network
// request and returns text results directly to the LLM so it can reason over them.
// Falls back to opening the browser for queries with no instant answer.
@available(iOS 18.1, *)
final class InternetSearchTool: Tool {
    let name = "internetSearch"
    let description = """
        Searches the internet and returns a summary of results. Use this for current \
        events, facts, prices, or anything the on-device model may not know.
        """

    @Generable
    struct Arguments {
        @Guide(description: "The search query, e.g. 'best sushi in San Jose' or 'weather in Tokyo tomorrow'.")
        var query: String
    }

    private struct DDGResponse: Decodable {
        let Abstract: String
        let AbstractText: String
        let AbstractSource: String
        let RelatedTopics: [RelatedTopic]

        struct RelatedTopic: Decodable {
            let Text: String?
        }
    }

    func call(arguments: Arguments) async throws -> ToolOutput {
        let encoded = arguments.query
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let url = URL(string: "https://api.duckduckgo.com/?q=\(encoded)&format=json&no_html=1&skip_disambig=1")!

        let (data, _) = try await URLSession.shared.data(from: url)

        if let result = try? JSONDecoder().decode(DDGResponse.self, from: data) {
            var parts: [String] = []

            if !result.AbstractText.isEmpty {
                let source = result.AbstractSource.isEmpty ? "" : " (via \(result.AbstractSource))"
                parts.append(result.AbstractText + source)
            }

            let topics = result.RelatedTopics
                .compactMap(\.Text)
                .filter { !$0.isEmpty }
                .prefix(3)
                .map { "• \($0)" }
            parts.append(contentsOf: topics)

            if !parts.isEmpty {
                return ToolOutput(parts.joined(separator: "\n"))
            }
        }

        // No instant answer — open browser so the user can read results themselves
        let safariURL  = URL(string: "https://www.google.com/search?q=\(encoded)")!
        let chromeURL  = URL(string: "googlechrome://www.google.com/search?q=\(encoded)")!

        await MainActor.run {
            if UIApplication.shared.canOpenURL(chromeURL) {
                UIApplication.shared.open(chromeURL)
            } else {
                UIApplication.shared.open(safariURL)
            }
        }

        return ToolOutput("No instant answer found for '\(arguments.query)' — opened search results in your browser.")
    }
}
