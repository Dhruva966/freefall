import EventKit
import Foundation
import FoundationModels

@available(iOS 26, *)
final class ReminderTool: Tool {
    typealias Output = String

    let name = "createReminder"
    let description = "Create a reminder at a specific time. Use when user says 'remind me', 'don't let me forget', 'ping me at'."

    struct Arguments: Generable {
        let title: String

        let datetime: String

        static var generationSchema: GenerationSchema {
            GenerationSchema(
                type: Self.self,
                description: "Arguments for creating a reminder.",
                properties: [
                    .init(name: "title", description: "The reminder title.", type: String.self),
                    .init(name: "datetime", description: "The reminder date and time in ISO 8601 format.", type: String.self)
                ]
            )
        }

        init(title: String, datetime: String) {
            self.title = title
            self.datetime = datetime
        }

        init(_ content: GeneratedContent) throws {
            self.title = try content.value(forProperty: "title")
            self.datetime = try content.value(forProperty: "datetime")
        }

        var generatedContent: GeneratedContent {
            GeneratedContent(properties: ["title": title, "datetime": datetime])
        }
    }

    func call(arguments: Arguments) async throws -> String {
        let store = EKEventStore()
        let granted = await requestReminderAccess(for: store)
        guard granted else {
            return "Couldn't get Reminders access."
        }

        let reminder = EKReminder(eventStore: store)
        reminder.title = arguments.title
        reminder.calendar = store.defaultCalendarForNewReminders()
        if let date = Self.dateFormatter.date(from: arguments.datetime) {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: date
            )
        }

        try store.save(reminder, commit: true)
        return "Done. Reminding you: \(arguments.title)."
    }

    private func requestReminderAccess(for store: EKEventStore) async -> Bool {
        await withCheckedContinuation { continuation in
            store.requestAccess(to: .reminder) { granted, _ in
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
