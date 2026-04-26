import Foundation
import FoundationModels

@available(iOS 26, *)
final class PrivateRouter: MessageRouting {
    // Private mode runs fully on-device with no internet. Only tools that work
    // offline are registered here. Weather, restaurants, travel, and web search
    // all require network access and are available in non-private mode only.
    private let reminderTool = ReminderTool()
    private let alarmTool = AlarmTool()
    private let calendarTool = CalendarTool()

    private lazy var session = LanguageModelSession(
        tools: [reminderTool, alarmTool, calendarTool],
        instructions: """
        You are Free Fall, a private on-device assistant. No internet connection is available.
        The user’s current date and time is injected into every message in ISO 8601 format.
        Use tools when the user wants to create a reminder, set an alarm, or add a calendar event.
        For anything requiring internet (weather, restaurants, search, directions), let the user \
        know private mode is offline-only and suggest switching to standard mode.
        If no tool is needed, answer concisely from your own knowledge.
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
