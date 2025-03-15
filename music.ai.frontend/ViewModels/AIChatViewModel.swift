import SwiftUI
import Combine

/// Message model for chat
struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isFromUser: Bool
    let timestamp: Date
    
    init(content: String, isFromUser: Bool, timestamp: Date = Date()) {
        self.content = content
        self.isFromUser = isFromUser
        self.timestamp = timestamp
    }
}

/// ViewModel for managing the AI chat sidebar
class AIChatViewModel: ObservableObject {
    /// The list of chat messages
    @Published var messages: [ChatMessage] = []
    
    /// The current message being typed
    @Published var currentMessage: String = ""
    
    /// Whether the sidebar is expanded
    @Published var isExpanded: Bool = true
    
    /// Send a message to the AI
    func sendMessage() {
        guard !currentMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Add user message
        let userMessage = ChatMessage(content: currentMessage, isFromUser: true)
        messages.append(userMessage)
        
        // Clear current message
        let sentMessage = currentMessage
        currentMessage = ""
        
        // Simulate AI response (in a real app, this would call an API)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Add AI response
            let aiResponse = ChatMessage(
                content: "I received your message: \"\(sentMessage)\". This is a placeholder response.",
                isFromUser: false
            )
            self.messages.append(aiResponse)
        }
    }
    
    /// Toggle the sidebar expansion state
    func toggleExpansion() {
        isExpanded.toggle()
    }
    
    /// Clear all messages
    func clearChat() {
        messages.removeAll()
    }
} 