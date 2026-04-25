import Foundation

// Sends message text to the mac-backend FastAPI server and returns the reply.
// The Mac handles routing, LLM inference, and AppleScript execution.
final class MacBackendRouter: MessageRouting {
    private let macIP: String

    init(macIP: String) {
        self.macIP = macIP
    }

    func route(_ message: String) async -> IntentResult {
        guard let url = URL(string: "http://\(macIP):8000/message") else {
            return error("Invalid Mac IP: \(macIP). Check settings.")
        }

        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["text": message, "sender": "ios-app"]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else {
            return error("Failed to encode request.")
        }
        req.httpBody = data

        do {
            let (responseData, _) = try await URLSession.shared.data(for: req)
            if let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let reply = json["reply"] as? String {
                return IntentResult(intent: .unknown, params: IntentParams(), response: reply)
            }
            return error("Unexpected response from Mac backend.")
        } catch {
            return self.error("Can't reach Mac at \(macIP):8000. Make sure the server is running.")
        }
    }

    private func error(_ message: String) -> IntentResult {
        IntentResult(intent: .unknown, params: IntentParams(), response: message)
    }
}
