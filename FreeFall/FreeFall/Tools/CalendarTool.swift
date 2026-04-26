import EventKit
import Foundation
import FoundationModels

@available(iOS 26, *)
final class CalendarTool: Tool {
    typealias Output = String

    let name = "createCalendarEvent"
    let description = "Create a calendar event. Use when user says 'schedule', 'add to calendar', 'meeting at'."

    @Generable
    struct Arguments {
        @Guide(description: "The event title.")
        var title: String

        @Guide(description: "Event start datetime in ISO 8601 format, e.g. 2025-04-26T14:00:00Z.")
        var start: String

        @Guide(description: "Event end datetime in ISO 8601 format. If not specified, 1 hour after start.")
        var end: String
    }

    func call(arguments: Arguments) async throws -> String {
        let store = EKEventStore()
        let granted = await withCheckedContinuation { continuation in
            store.requestAccess(to: .event) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
        guard granted else { return "Couldn't get Calendar access." }

        let event = EKEvent(eventStore: store)
        event.title = arguments.title
        event.calendar = store.defaultCalendarForNewEvents
        event.startDate = dateFormatter.date(from: arguments.start) ?? Date()
        event.endDate = dateFormatter.date(from: arguments.end) ?? event.startDate.addingTimeInterval(3600)
        try store.save(event, span: .thisEvent, commit: true)
        return "Done. Added \(arguments.title) to your calendar."
    }

    private let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}
