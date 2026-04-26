import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        let isUser = message.role == .user
        HStack {
            if isUser { Spacer(minLength: 50) }

            Text(message.text)
                .font(.subheadline)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(isUser ? Color.blue : Color(.systemGray5))
                .foregroundColor(isUser ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            if !isUser { Spacer(minLength: 50) }
        }
        .padding(.horizontal, 10)
    }
}

#Preview {
    VStack(spacing: 8) {
        MessageBubble(message: ChatMessage(role: .user, text: "Remind me to study at 7"))
        MessageBubble(message: ChatMessage(role: .assistant, text: "Done. I'll remind you at 7 PM."))
    }
    .padding(.vertical)
}
