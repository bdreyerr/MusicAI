import Foundation
import SwiftUI

/// Represents an audio clip in the timeline
struct AudioClip: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var startBeat: Double // Position in the timeline (in beats)
    var duration: Double // Duration in beats
    var color: Color? // Optional custom color for the clip
    var waveformData: [Float] = [] // Placeholder for waveform visualization data
    var audioFileURL: URL? // URL to the audio file on disk
    
    // Coding keys for Codable
    enum CodingKeys: String, CodingKey {
        case id, name, startBeat, duration, colorData, waveformData, audioFileURL
    }
    
    init(id: UUID = UUID(), name: String, startBeat: Double, duration: Double, audioFileURL: URL? = nil, color: Color? = nil, waveformData: [Float] = []) {
        self.id = id
        self.name = name
        self.startBeat = startBeat
        self.duration = duration
        self.audioFileURL = audioFileURL
        self.color = color
        self.waveformData = waveformData
    }
    
    // Custom initializer from decoder
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        startBeat = try container.decode(Double.self, forKey: .startBeat)
        duration = try container.decode(Double.self, forKey: .duration)
        waveformData = try container.decode([Float].self, forKey: .waveformData)
        audioFileURL = try container.decodeIfPresent(URL.self, forKey: .audioFileURL)
        
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
        try container.encode(waveformData, forKey: .waveformData)
        try container.encodeIfPresent(audioFileURL, forKey: .audioFileURL)
        
        // Encode optional color
        if let clipColor = color {
            try container.encode(CodableColor(color: clipColor), forKey: .colorData)
        }
    }
    
    // Computed property to get the end beat position
    var endBeat: Double {
        return startBeat + duration
    }
    
    // Get the filename from the URL
    var filename: String {
        if let audioFileURL {
            return audioFileURL.lastPathComponent
        } else {
            return "File not Found"
        }
    }
    
    // Check if the audio file exists
    var fileExists: Bool {
        if let audioFileURL {
            return FileManager.default.fileExists(atPath: audioFileURL.path)
        } else {
            return false
        }
    }
    
    // Create a new audio clip with a file URL
    static func create(name: String, startBeat: Double, duration: Double, audioFileURL: URL? = nil, color: Color? = nil) -> AudioClip {
        return AudioClip(name: name, startBeat: startBeat, duration: duration, audioFileURL: audioFileURL, color: color)
    }
    
    // Implement Equatable to help with updates
    static func == (lhs: AudioClip, rhs: AudioClip) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.startBeat == rhs.startBeat &&
               lhs.duration == rhs.duration &&
               lhs.audioFileURL == rhs.audioFileURL
    }
} 
