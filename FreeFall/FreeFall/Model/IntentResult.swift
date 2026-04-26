import Foundation

enum Intent: String, Codable {
    case createReminder  = "create_reminder"
    case getWeather      = "get_weather"
    case createCalendarEvent = "create_calendar_event"
    case setAlarm        = "set_alarm"
    case searchGmail     = "search_gmail"
    case clarify         = "clarify"
    case unknown         = "unknown"
}

struct IntentParams: Codable {
    // create_reminder
    var title: String?
    var datetime: String?   // ISO8601

    // get_weather
    var when: String?       // "today" | "tomorrow" | ISO8601 date

    // create_calendar_event
    var start: String?      // ISO8601
    var end: String?        // ISO8601

    // set_alarm
    var time: String?       // "HH:MM"

    // search_gmail
    var query: String?
}

struct IntentResult: Codable {
    let intent: Intent
    let params: IntentParams
    let response: String
    var actions: [DeviceAction] = []

    static let unknown = IntentResult(
        intent: .unknown,
        params: IntentParams(),
        response: "I didn't catch that. Try: \"Remind me to...\", \"What's the weather...\", or \"Add [event] to my calendar.\""
    )
}
