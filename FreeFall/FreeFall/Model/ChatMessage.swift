import Foundation

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    enum Role: String, Codable { case user, assistant }
    let role: Role
    let text: String

    init(role: Role, text: String) {
        self.id   = UUID()
        self.role = role
        self.text = text
    }
}
