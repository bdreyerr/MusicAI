import Foundation
import SwiftUI

/// Represents a MIDI clip in the timeline
struct MidiClip: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var startBeat: Double // Position in the timeline (in beats)
    var duration: Double // Duration in beats
    var color: Color? // Optional custom color for the clip
    var notes: [MidiNote] = [] // MIDI notes contained in the clip
    
    // Coding keys for Codable
    enum CodingKeys: String, CodingKey {
        case id, name, startBeat, duration, colorData, notes
    }
    
    init(id: UUID = UUID(), name: String, startBeat: Double, duration: Double, color: Color? = nil, notes: [MidiNote] = []) {
        self.id = id
        self.name = name
        self.startBeat = startBeat
        self.duration = duration
        self.color = color
        self.notes = notes
    }
    
    // Custom initializer from decoder
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        startBeat = try container.decode(Double.self, forKey: .startBeat)
        duration = try container.decode(Double.self, forKey: .duration)
        notes = try container.decode([MidiNote].self, forKey: .notes)
        
        // Decode optional color
        if let colorData = try container.decodeIfPresent(CodableColor.self, forKey: .colorData) {
            color = colorData.color
        } else {
            color = nil
        }
    }
    
    // Custom encoder
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(startBeat, forKey: .startBeat)
        try container.encode(duration, forKey: .duration)
        try container.encode(notes, forKey: .notes)
        
        // Encode optional color
        if let clipColor = color {
            try container.encode(CodableColor(color: clipColor), forKey: .colorData)
        }
    }
    
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
struct MidiNote: Identifiable, Equatable, Codable {
    let id: UUID
    var pitch: Int // MIDI note number (0-127)
    var startBeat: Double // Start position relative to clip start (in beats)
    var duration: Double // Duration in beats
    var velocity: Int // Note velocity (0-127)
    
    init(id: UUID = UUID(), pitch: Int, startBeat: Double, duration: Double, velocity: Int) {
        self.id = id
        self.pitch = pitch
        self.startBeat = startBeat
        self.duration = duration
        self.velocity = velocity
    }
    
    // Computed property to get the end beat position
    var endBeat: Double {
        return startBeat + duration
    }
    
    // Implement Equatable
    static func == (lhs: MidiNote, rhs: MidiNote) -> Bool {
        return lhs.id == rhs.id &&
               lhs.pitch == rhs.pitch &&
               lhs.startBeat == rhs.startBeat &&
               lhs.duration == rhs.duration &&
               lhs.velocity == rhs.velocity
    }
} 
