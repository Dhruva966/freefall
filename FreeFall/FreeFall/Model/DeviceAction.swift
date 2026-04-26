import Foundation

enum DeviceAction: Codable {
    case setAlarm(time: String, label: String)
    case createReminder(title: String, datetime: String)
    case createCalendarEvent(title: String, start: String, end: String)
    case runShortcut(name: String)

    private enum CodingKeys: String, CodingKey {
        case type
        case time
        case label
        case title
        case datetime
        case start
        case end
        case name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "set_alarm":
            self = .setAlarm(
                time: try container.decode(String.self, forKey: .time),
                label: try container.decodeIfPresent(String.self, forKey: .label) ?? "Alarm"
            )
        case "create_reminder":
            self = .createReminder(
                title: try container.decode(String.self, forKey: .title),
                datetime: try container.decode(String.self, forKey: .datetime)
            )
        case "create_calendar_event":
            self = .createCalendarEvent(
                title: try container.decode(String.self, forKey: .title),
                start: try container.decode(String.self, forKey: .start),
                end: try container.decode(String.self, forKey: .end)
            )
        case "run_shortcut":
            self = .runShortcut(name: try container.decode(String.self, forKey: .name))
        default:
            // Unknown action type — skip gracefully rather than failing the whole response
            self = .runShortcut(name: "")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .setAlarm(let time, let label):
            try container.encode("set_alarm", forKey: .type)
            try container.encode(time, forKey: .time)
            try container.encode(label, forKey: .label)
        case .createReminder(let title, let datetime):
            try container.encode("create_reminder", forKey: .type)
            try container.encode(title, forKey: .title)
            try container.encode(datetime, forKey: .datetime)
        case .createCalendarEvent(let title, let start, let end):
            try container.encode("create_calendar_event", forKey: .type)
            try container.encode(title, forKey: .title)
            try container.encode(start, forKey: .start)
            try container.encode(end, forKey: .end)
        case .runShortcut(let name):
            try container.encode("run_shortcut", forKey: .type)
            try container.encode(name, forKey: .name)
        }
    }
}
