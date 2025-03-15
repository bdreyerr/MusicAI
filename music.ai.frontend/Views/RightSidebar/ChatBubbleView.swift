import SwiftUI

struct ChatBubbleView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer()
            }
            
            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(10)
                    .background(
                        message.isFromUser ? 
                            themeManager.secondaryTextColor.opacity(0.8) : 
                            themeManager.tertiaryBackgroundColor
                    )
                    .foregroundColor(
                        message.isFromUser ? 
                            Color.white : 
                            themeManager.primaryTextColor
                    )
                    .cornerRadius(12)
                
                Text(formatTimestamp(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(themeManager.secondaryTextColor)
                    .padding(.horizontal, 4)
            }
            .frame(maxWidth: 280, alignment: message.isFromUser ? .trailing : .leading)
            
            if !message.isFromUser {
                Spacer()
            }
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    VStack {
        ChatBubbleView(message: ChatMessage(content: "Hello, how can I help you today?", isFromUser: false))
        ChatBubbleView(message: ChatMessage(content: "I need help with my music project", isFromUser: true))
    }
    .padding()
    .environmentObject(ThemeManager())
} 
