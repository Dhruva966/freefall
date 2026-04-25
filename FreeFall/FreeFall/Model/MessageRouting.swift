import Foundation

protocol MessageRouting {
    func route(_ message: String) async -> IntentResult
}

// Drop-in mock — returns predictable IntentResults without any model.
// Swap for MessageRouter once Gemma270M.mlpackage lands.
final class MockMessageRouter: MessageRouting {
    func route(_ message: String) async -> IntentResult {
        let lower = message.lowercased()

        if lower.contains("remind") {
            return IntentResult(
                intent: .createReminder,
                params: IntentParams(title: "study", datetime: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600))),
                response: "Done. I'll remind you in an hour."
            )
        }
        if lower.contains("weather") {
            return IntentResult(
                intent: .getWeather,
                params: IntentParams(when: "today"),
                response: "Checking today's weather..."
            )
        }
        if lower.contains("calendar") || lower.contains("add") || lower.contains("practice") || lower.contains("meeting") {
            let start = ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600))
            let end   = ISO8601DateFormatter().string(from: Date().addingTimeInterval(7200))
            return IntentResult(
                intent: .createCalendarEvent,
                params: IntentParams(title: "Event", datetime: nil, when: nil, start: start, end: end),
                response: "Added to your calendar."
            )
        }
        if lower.contains("alarm") || lower.contains("wake") {
            return IntentResult(
                intent: .setAlarm,
                params: IntentParams(time: "07:00"),
                response: "Opening alarm for 7 AM — tap Set to confirm."
            )
        }
        return .unknown
    }
}
