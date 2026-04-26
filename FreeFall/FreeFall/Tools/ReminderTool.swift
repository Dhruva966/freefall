import EventKit
import Foundation
import FoundationModels

@available(iOS 26, *)
final class ReminderTool: Tool {
    typealias Output = String

    let name = "createReminder"
    let description = "Create a reminder at a specific time. Use when user says 'remind me', 'don't let me forget', 'ping me at'."

    @Generable
    struct Arguments {
        @Guide(description: "The reminder title or what to be reminded about.")
        var title: String

        @Guide(description: "When to remind, in ISO 8601 format, e.g. 2025-04-26T09:00:00Z.")
        var datetime: String
    }

    func call(arguments: Arguments) async throws -> String {
        let store = EKEventStore()
        let granted = await withCheckedContinuation { continuation in
            store.requestAccess(to: .reminder) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
        guard granted else { return "Couldn't get Reminders access." }

        let reminder = EKReminder(eventStore: store)
        reminder.title = arguments.title
        reminder.calendar = store.defaultCalendarForNewReminders()
        if let date = dateFormatter.date(from: arguments.datetime) {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: date
            )
        }
        try store.save(reminder, commit: true)
        return "Done. Reminding you: \(arguments.title)."
    }

    private let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}
