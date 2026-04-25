import Foundation

// Mac backend handles all execution. This just unwraps the response string.
final class ActionExecutor {
    func execute(_ result: IntentResult) async -> String {
        result.response
    }
}
