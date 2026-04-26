import Foundation
import EventKit
import UIKit

@MainActor
final class ActionExecutor {
    private let eventStore = EKEventStore()

    func execute(_ result: IntentResult) async -> String {
        for action in result.actions {
            if case .runShortcut(let name) = action, name.isEmpty { continue }
            await executeAction(action)
        }
        return result.response
    }

    private func executeAction(_ action: DeviceAction) async {
        switch action {
        case .createReminder(let title, let datetimeStr):
            await createReminder(title: title, datetimeStr: datetimeStr)
        case .createCalendarEvent(let title, let start, let end):
            await createCalendarEvent(title: title, start: start, end: end)
        case .setAlarm(let time, let label):
            await triggerAlarmShortcut(time: time, label: label)
        case .runShortcut(let name):
            await runShortcut(name: name)
        }
    }

    private func createReminder(title: String, datetimeStr: String) async {
        let granted = await withCheckedContinuation { continuation in
            eventStore.requestAccess(to: .reminder) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
        guard granted else { return }
        do {
            let reminder = EKReminder(eventStore: eventStore)
            reminder.title = title
            reminder.calendar = eventStore.defaultCalendarForNewReminders()
            if let date = ISO8601DateFormatter().date(from: datetimeStr) {
                reminder.dueDateComponents = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute], from: date)
            }
            try eventStore.save(reminder, commit: true)
        } catch {
            print("[ActionExecutor] reminder error: \(error)")
        }
    }

    private func createCalendarEvent(title: String, start: String, end: String) async {
        let granted = await withCheckedContinuation { continuation in
            eventStore.requestAccess(to: .event) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
        guard granted else { return }
        do {
            let event = EKEvent(eventStore: eventStore)
            event.title = title
            event.calendar = eventStore.defaultCalendarForNewEvents
            let fmt = ISO8601DateFormatter()
            event.startDate = fmt.date(from: start) ?? Date()
            event.endDate = fmt.date(from: end) ?? Date().addingTimeInterval(3600)
            try eventStore.save(event, span: .thisEvent, commit: true)
        } catch {
            print("[ActionExecutor] calendar error: \(error)")
        }
    }

    private func triggerAlarmShortcut(time: String, label: String) async {
        let encoded = "\(time),\(label)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? time
        if let url = URL(string: "shortcuts://run-shortcut?name=FreeFall-SetAlarm&input=\(encoded)") {
            await UIApplication.shared.open(url)
        }
    }

    private func runShortcut(name: String) async {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        if let url = URL(string: "shortcuts://run-shortcut?name=\(encoded)") {
            await UIApplication.shared.open(url)
        }
    }
}
