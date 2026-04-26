import EventKit
import Foundation
import FoundationModels

@available(iOS 26, *)
final class CalendarTool: Tool {
    typealias Output = String

    let name = "createCalendarEvent"
    let description = "Create a calendar event. Use when user says 'schedule', 'add to calendar', 'meeting'."

    struct Arguments: Generable {
        let title: String

        let start: String

        let end: String

        static var generationSchema: GenerationSchema {
            GenerationSchema(
                type: Self.self,
                description: "Arguments for creating a calendar event.",
                properties: [
                    .init(name: "title", description: "The calendar event title.", type: String.self),
                    .init(name: "start", description: "The event start datetime in ISO 8601 format.", type: String.self),
                    .init(name: "end", description: "The event end datetime in ISO 8601 format.", type: String.self)
                ]
            )
        }

        init(title: String, start: String, end: String) {
            self.title = title
            self.start = start
            self.end = end
        }

        init(_ content: GeneratedContent) throws {
            self.title = try content.value(forProperty: "title")
            self.start = try content.value(forProperty: "start")
            self.end = try content.value(forProperty: "end")
        }

        var generatedContent: GeneratedContent {
            GeneratedContent(properties: ["title": title, "start": start, "end": end])
        }
    }

    func call(arguments: Arguments) async throws -> String {
        let store = EKEventStore()
        let granted = await requestCalendarAccess(for: store)
        guard granted else {
            return "Couldn't get Calendar access."
        }

        let formatter = Self.dateFormatter
        let event = EKEvent(eventStore: store)
        event.title = arguments.title
        event.calendar = store.defaultCalendarForNewEvents
        event.startDate = formatter.date(from: arguments.start) ?? Date()
        event.endDate = formatter.date(from: arguments.end) ?? event.startDate.addingTimeInterval(3600)

        try store.save(event, span: .thisEvent, commit: true)
        return "Done. Added \(arguments.title) to your calendar."
    }

    private func requestCalendarAccess(for store: EKEventStore) async -> Bool {
        await withCheckedContinuation { continuation in
            store.requestAccess(to: .event) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
