import SwiftUI

struct ChatMessageView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var viewModel: AIChatViewModel
    let message: ChatMessage
    
    var body: some View {
        VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 8) {
            if message.isFromUser {
                // User message styled like the input box
                VStack(alignment: .leading, spacing: 8) {
                    // Tracks included in chat context (if any)
                    if !message.attachedTrackIds.isEmpty {
                        // Use ScrollView to match the input box style
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(message.attachedTrackIds, id: \.self) { trackId in
                                    if let track = viewModel.getTrack(by: trackId) {
                                        // This HStack matches exactly the one in RightSidebarView
                                        HStack(spacing: 4) {
                                            Image(systemName: track.type.icon)
                                                .font(.system(size: 10))
                                                .foregroundColor(track.customColor ?? track.type.color)
                                            
                                            Text(track.name)
                                                .font(.system(size: 10))
                                                .foregroundColor(themeManager.secondaryTextColor)
                                        }
                                        .padding(3)
                                        .background(themeManager.backgroundColor)
                                        .cornerRadius(4)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Message content with proper text wrapping
                    Text(message.content)
                        .foregroundColor(themeManager.primaryTextColor)
                        .padding(8)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(8)
                .background(themeManager.secondaryBackgroundColor)
                .cornerRadius(8)
                .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                // AI response with proper text wrapping
                Text(message.content)
                    .foregroundColor(themeManager.primaryTextColor)
                    .padding(8)
                    .fixedSize(horizontal: false, vertical: true)
                    .background(themeManager.secondaryBackgroundColor)
                    .cornerRadius(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Timestamp
            Text(formatTimestamp(message.timestamp))
                .font(.caption2)
                .foregroundColor(themeManager.secondaryTextColor)
                .padding(.horizontal, 4)
                .frame(maxWidth: .infinity, alignment: message.isFromUser ? .trailing : .leading)
        }
        .padding(.vertical, 4)
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    let projectViewModel = ProjectViewModel()
    let aiChatViewModel = AIChatViewModel(projectViewModel: projectViewModel)
    
    return VStack {
        ChatMessageView(message: ChatMessage(
            content: "Hello, how can I help you today?",
            isFromUser: false,
            attachedTrackIds: []
        ))
        
        ChatMessageView(message: ChatMessage(
            content: "I need help with my music project. This is a longer message that should wrap to multiple lines to demonstrate the text wrapping functionality.",
            isFromUser: true,
            attachedTrackIds: projectViewModel.tracks.prefix(2).map { $0.id }
        ))
    }
    .padding()
    .environmentObject(ThemeManager())
    .environmentObject(aiChatViewModel)
} 
