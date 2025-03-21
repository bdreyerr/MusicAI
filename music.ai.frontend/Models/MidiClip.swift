import Foundation
import SwiftUI

/// Represents a MIDI clip in the timeline
struct MidiClip: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var startBeat: Double // Position in the timeline (in beats)
    var duration: Double // Duration in beats
    var color: Color? // Optional custom color for the clip
    var notes: [MidiNote] = [] // MIDI notes contained in the clip
    
    // Computed property to get the end beat position
    var endBeat: Double {
        return startBeat + duration
    }
    
    // Create a new empty MIDI clip
    static func createEmpty(name: String, startBeat: Double, duration: Double, color: Color? = nil) -> MidiClip {
        return MidiClip(name: name, startBeat: startBeat, duration: duration, color: color)
    }
    
    // Implement Equatable to help with updates
    static func == (lhs: MidiClip, rhs: MidiClip) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.startBeat == rhs.startBeat &&
               lhs.duration == rhs.duration
    }
}

/// Represents a single MIDI note in a clip
struct MidiNote: Identifiable {
    let id = UUID()
    var pitch: Int // MIDI note number (0-127)
    var startBeat: Double // Start position relative to clip start (in beats)
    var duration: Double // Duration in beats
    var velocity: Int // Note velocity (0-127)
    
    // Computed property to get the end beat position
    var endBeat: Double {
        return startBeat + duration
    }
} 