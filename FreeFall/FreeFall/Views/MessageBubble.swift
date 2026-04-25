import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 50) }

            Text(message.text)
                .font(.subheadline)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(message.isUser ? Color.blue : Color(.systemGray5))
                .foregroundColor(message.isUser ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            if !message.isUser { Spacer(minLength: 50) }
        }
        .padding(.horizontal, 10)
    }
}

#Preview {
    VStack(spacing: 8) {
        MessageBubble(message: ChatMessage(text: "Remind me to study at 7", isUser: true))
        MessageBubble(message: ChatMessage(text: "Done. I'll remind you at 7 PM.", isUser: false))
    }
    .padding(.vertical)
}
