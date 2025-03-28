import Foundation
import SwiftUI

/// Represents an audio clip in the timeline
struct AudioClip: Identifiable, Equatable, Codable {
    let id: UUID
    var audioItem: AudioItem
    var name: String
    var startBeat: Double // Position in the timeline (in beats)
    var duration: Double // Duration in beats
    var originalDuration: Double? // Original duration of the audio file in beats (if available)
    var color: Color? // Optional custom color for the clip
    var audioFileURL: URL? // URL to the audio file on disk
    var waveform: Waveform? // Optional waveform visualization data
    
    // Window into the original audio file
    var audioStartTime: Double // Start time in seconds within the original audio file
    var audioEndTime: Double // End time in seconds within the original audio file
    var audioWindowDuration: Double { audioEndTime - audioStartTime } // Duration of the window in seconds
    
    
    // Coding keys for Codable
    enum CodingKeys: String, CodingKey {
        case id, audioItem, name, startBeat, duration, originalDuration, colorData, audioFileURL, waveform, audioStartTime, audioEndTime
    }
    
    init(id: UUID = UUID(), audioItem: AudioItem, name: String, startBeat: Double, duration: Double,
         audioFileURL: URL? = nil, color: Color? = nil, originalDuration: Double? = nil,
         waveform: Waveform? = nil,
         audioStartTime: Double? = nil, audioEndTime: Double? = nil) {
        self.id = id
        self.audioItem = audioItem
        self.name = name
        self.startBeat = startBeat
        self.duration = duration
        self.audioFileURL = audioFileURL
        self.color = color
        self.originalDuration = originalDuration
        
        // Generate a random waveform if none was provided
        if waveform == nil {
            self.waveform = AudioWaveformGenerator.generateRandomWaveform(
                color: color
            )
        } else {
            self.waveform = waveform
        }
        
        // Initialize the audio window to the full duration if not specified
        self.audioStartTime = audioStartTime ?? 0
        self.audioEndTime = audioEndTime ?? audioItem.duration
    }
    
    // Custom initializer from decoder
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        audioItem = try container.decode(AudioItem.self, forKey: .audioItem)
        name = try container.decode(String.self, forKey: .name)
        startBeat = try container.decode(Double.self, forKey: .startBeat)
        duration = try container.decode(Double.self, forKey: .duration)
        originalDuration = try container.decodeIfPresent(Double.self, forKey: .originalDuration)
        audioFileURL = try container.decodeIfPresent(URL.self, forKey: .audioFileURL)
        waveform = try container.decodeIfPresent(Waveform.self, forKey: .waveform)
        
        // Decode optional color
        if let colorData = try container.decodeIfPresent(CodableColor.self, forKey: .colorData) {
            color = colorData.color
        } else {
            color = nil
        }
        
        // Decode audio window values, defaulting to full duration if not present
        audioStartTime = try container.decodeIfPresent(Double.self, forKey: .audioStartTime) ?? 0
        audioEndTime = try container.decodeIfPresent(Double.self, forKey: .audioEndTime) ?? audioItem.duration
        
        // Generate a random waveform if none was decoded
        if waveform == nil {
            self.waveform = AudioWaveformGenerator.generateRandomWaveform(
                color: color
            )
        }
    }
    
    // Custom encoder
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(audioItem, forKey: .audioItem)
        try container.encode(name, forKey: .name)
        try container.encode(startBeat, forKey: .startBeat)
        try container.encode(duration, forKey: .duration)
        try container.encodeIfPresent(originalDuration, forKey: .originalDuration)
        try container.encodeIfPresent(audioFileURL, forKey: .audioFileURL)
        try container.encodeIfPresent(waveform, forKey: .waveform)
        try container.encode(audioStartTime, forKey: .audioStartTime)
        try container.encode(audioEndTime, forKey: .audioEndTime)
        
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
    static func create(audioItem: AudioItem, name: String, startBeat: Double, duration: Double, audioFileURL: URL? = nil, color: Color? = nil, originalDuration: Double? = nil, waveform: Waveform? = nil, audioStartTime: Double? = nil, audioEndTime: Double? = nil) -> AudioClip {
        return AudioClip(
            audioItem: audioItem,
            name: name,
            startBeat: startBeat,
            duration: duration,
            audioFileURL: audioFileURL,
            color: color,
            originalDuration: originalDuration,
            waveform: waveform,
            audioStartTime: audioStartTime,
            audioEndTime: audioEndTime
        )
    }
    
    // Create an empty audio clip (for UI testing or placeholders)
    static func createEmpty(audioItem: AudioItem, name: String, startBeat: Double, duration: Double, color: Color? = nil, waveform: Waveform? = nil) -> AudioClip {
        return AudioClip(
            audioItem: audioItem,
            name: name,
            startBeat: startBeat,
            duration: duration,
            color: color,
            waveform: waveform,
            audioStartTime: 0,
            audioEndTime: audioItem.duration
        )
    }
    
    // Implement Equatable to help with updates
    static func == (lhs: AudioClip, rhs: AudioClip) -> Bool {
        return lhs.id == rhs.id &&
               lhs.audioItem.id == rhs.audioItem.id &&
               lhs.name == rhs.name &&
               lhs.startBeat == rhs.startBeat &&
               lhs.duration == rhs.duration &&
               lhs.originalDuration == rhs.originalDuration &&
               lhs.audioFileURL == rhs.audioFileURL &&
               lhs.waveform?.id == rhs.waveform?.id
    }
} 
