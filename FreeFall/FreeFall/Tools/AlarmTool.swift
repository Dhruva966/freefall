import Foundation
import FoundationModels
import UIKit

@available(iOS 26, *)
final class AlarmTool: Tool {
    typealias Output = String

    let name = "setAlarm"
    let description = "Set an alarm. Use when user says 'set alarm', 'wake me up', 'alarm at'."

    @Generable
    struct Arguments {
        @Guide(description: "Alarm time in HH:MM 24-hour format, e.g. 07:30.")
        var time: String

        @Guide(description: "Short label for the alarm, e.g. 'Morning workout'.")
        var label: String
    }

    func call(arguments: Arguments) async throws -> String {
        let rawInput = "\(arguments.time),\(arguments.label)"
        let encoded = rawInput.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? rawInput
        await MainActor.run {
            UIApplication.shared.open(
                URL(string: "shortcuts://run-shortcut?name=FreeFall-SetAlarm&input=\(encoded)")!
            )
        }
        return "Alarm set for \(arguments.time)."
    }
}
