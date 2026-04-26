import Foundation
import FoundationModels

@available(iOS 26, *)
final class PrivateRouter: MessageRouting {
    private let reminderTool = ReminderTool()
    private let alarmTool = AlarmTool()
    private let calendarTool = CalendarTool()

    private lazy var session = LanguageModelSession(
        tools: [reminderTool, alarmTool, calendarTool],
        instructions: """
        You are Free Fall, a smart iPhone assistant running entirely on-device.
        The user’s current date and time is injected into every message in ISO 8601 format.
        Use tools only when the user clearly wants to create a reminder, set an alarm, or create a calendar event.
        If a tool is not needed, answer normally and concisely.
        """
    )

    func route(_ message: String) async -> IntentResult {
        guard case .available = SystemLanguageModel.default.availability else {
            return IntentResult(
                intent: .unknown,
                params: IntentParams(),
                response: "Private Mode requires Apple Intelligence on a supported iPhone."
            )
        }

        let now = ISO8601DateFormatter().string(from: Date())
        let timestampedMessage = "Current date/time: \(now)\n\nUser: \(message)"

        do {
            let response = try await session.respond(to: timestampedMessage)
            return IntentResult(
                intent: .unknown,
                params: IntentParams(),
                response: response.content
            )
        } catch {
            return IntentResult(
                intent: .unknown,
                params: IntentParams(),
                response: error.localizedDescription
            )
        }
    }
}
