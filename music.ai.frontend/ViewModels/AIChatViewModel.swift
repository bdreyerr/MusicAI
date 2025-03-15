import SwiftUI
import Combine

/// Message model for chat
struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isFromUser: Bool
    let timestamp: Date
    let attachedTrackIds: [UUID]
    
    init(content: String, isFromUser: Bool, timestamp: Date = Date(), attachedTrackIds: [UUID] = []) {
        self.content = content
        self.isFromUser = isFromUser
        self.timestamp = timestamp
        self.attachedTrackIds = attachedTrackIds
    }
}

/// ViewModel for managing the AI chat sidebar
class AIChatViewModel: ObservableObject {
    /// The list of chat messages
    @Published var messages: [ChatMessage] = []
    
    /// The current message being typed
    @Published var currentMessage: String = ""
    
    /// Track IDs attached to the current message
    @Published var attachedTrackIds: [UUID] = []
    
    /// Whether the sidebar is expanded
    @Published var isExpanded: Bool = true
    
    /// Reference to the project view model
    private weak var projectViewModel: ProjectViewModel?
    
    /// Initialize with project view model
    init(projectViewModel: ProjectViewModel? = nil) {
        self.projectViewModel = projectViewModel
    }
    
    /// Set the project view model
    func setProjectViewModel(_ viewModel: ProjectViewModel) {
        self.projectViewModel = viewModel
    }
    
    /// Get the project view model
    func getProjectViewModel() -> ProjectViewModel? {
        return projectViewModel
    }
    
    /// Get all available tracks from the project
    var availableTracks: [Track] {
        return projectViewModel?.tracks ?? []
    }
    
    /// Get track by ID
    func getTrack(by id: UUID) -> Track? {
        return projectViewModel?.tracks.first { $0.id == id }
    }
    
    /// Send a message to the AI
    func sendMessage() {
        guard !currentMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Add user message
        let userMessage = ChatMessage(
            content: currentMessage,
            isFromUser: true,
            attachedTrackIds: attachedTrackIds
        )
        messages.append(userMessage)
        
        // Clear current message and attached tracks
        let sentMessage = currentMessage
        currentMessage = ""
        let sentTrackIds = attachedTrackIds
        attachedTrackIds = []
        
        // Simulate AI response (in a real app, this would call an API)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Get track names for the response
            let trackNames = sentTrackIds.compactMap { id in
                self.getTrack(by: id)?.name
            }
            
            // Add AI response
            let tracksInfo = trackNames.isEmpty ? "" : " with tracks: \(trackNames.joined(separator: ", "))"
            let aiResponse = ChatMessage(
                content: "I received your message\(tracksInfo): \"\(sentMessage)\". This is a placeholder response.",
                isFromUser: false
            )
            self.messages.append(aiResponse)
        }
    }
    
    /// Add a track to the current message
    func attachTrack(_ trackId: UUID) {
        if !attachedTrackIds.contains(trackId) {
            attachedTrackIds.append(trackId)
        }
    }
    
    /// Remove a track from the current message
    func removeTrack(_ trackId: UUID) {
        attachedTrackIds.removeAll { $0 == trackId }
    }
    
    /// Toggle the sidebar expansion state
    func toggleExpansion() {
        isExpanded.toggle()
    }
    
    /// Clear all messages
    func clearChat() {
        messages.removeAll()
        attachedTrackIds.removeAll()
    }
} 