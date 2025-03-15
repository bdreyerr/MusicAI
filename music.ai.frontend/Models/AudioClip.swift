import Foundation
import SwiftUI

/// Represents an audio clip in the timeline
struct AudioClip: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var startBeat: Double // Position in the timeline (in beats)
    var duration: Double // Duration in beats
    var color: Color? // Optional custom color for the clip
    var waveformData: [Float] = [] // Placeholder for waveform visualization data
    
    // Computed property to get the end beat position
    var endBeat: Double {
        return startBeat + duration
    }
    
    // Create a new empty audio clip
    static func createEmpty(name: String, startBeat: Double, duration: Double) -> AudioClip {
        return AudioClip(name: name, startBeat: startBeat, duration: duration)
    }
    
    // Implement Equatable to help with updates
    static func == (lhs: AudioClip, rhs: AudioClip) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.startBeat == rhs.startBeat &&
               lhs.duration == rhs.duration
    }
} 