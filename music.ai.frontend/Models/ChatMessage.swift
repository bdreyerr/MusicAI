//
//  ChatMessage.swift
//  music.ai.frontend
//
//  Created by Ben Dreyer on 3/15/25.
//

import Foundation


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
