import Foundation
import FoundationModels
import UIKit

@available(iOS 26, *)
final class AlarmTool: Tool {
    typealias Output = String

    let name = "setAlarm"
    let description = "Set an alarm. Use when user says 'set alarm', 'wake me up', 'alarm at'."

    struct Arguments: Generable {
        let time: String

        let label: String

        static var generationSchema: GenerationSchema {
            GenerationSchema(
                type: Self.self,
                description: "Arguments for setting an alarm.",
                properties: [
                    .init(name: "time", description: "The alarm time in HH:MM 24-hour format.", type: String.self),
                    .init(name: "label", description: "The label for the alarm.", type: String.self)
                ]
            )
        }

        init(time: String, label: String) {
            self.time = time
            self.label = label
        }

        init(_ content: GeneratedContent) throws {
            self.time = try content.value(forProperty: "time")
            self.label = try content.value(forProperty: "label")
        }

        var generatedContent: GeneratedContent {
            GeneratedContent(properties: ["time": time, "label": label])
        }
    }

    func call(arguments: Arguments) async throws -> String {
        let rawInput = "\(arguments.time),\(arguments.label)"
        let encodedInput = rawInput.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? rawInput
        await MainActor.run {
            UIApplication.shared.open(
                URL(string: "shortcuts://run-shortcut?name=FreeFall-SetAlarm&input=\(encodedInput)")!
            )
        }
        return "Alarm set for \(arguments.time)."
    }
}
