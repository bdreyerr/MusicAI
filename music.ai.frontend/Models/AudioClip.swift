import Foundation
import SwiftUI

/// Represents an audio clip in the timeline
struct AudioClip: Identifiable, Equatable, Codable {
    let id: UUID
    var audioItem: AudioItem // The Audio Item represents the original file
    var name: String
    var startPositionInBeats: Double // Position in the timeline (in beats)
    var durationInBeats: Double // Duration in beats
    var originalDuration: Double? // Original duration of the audio file in beats (if available)
    var color: Color? // Optional custom color for the clip
    var audioFileURL: URL? // URL to the audio file on disk
    var waveform: Waveform? // Optional waveform visualization data
    
    // Sample-based window into the original audio file
    var startOffsetInSamples: Int64 // Start position in samples within the original audio file
    var lengthInSamples: Int64 // Length in samples of the audio window
    
    // Computed properties for compatibility and convenience
    var endBeat: Double { startPositionInBeats + durationInBeats }
    
    // Calculate seconds-based values when needed
    var audioStartTime: Double { Double(startOffsetInSamples) / audioItem.sampleRate }
    var audioEndTime: Double { Double(startOffsetInSamples + lengthInSamples) / audioItem.sampleRate }
    var audioWindowDuration: Double { Double(lengthInSamples) / audioItem.sampleRate }
    
    // Coding keys for Codable
    enum CodingKeys: String, CodingKey {
        case id, audioItem, name, startPositionInBeats, durationInBeats, originalDuration, colorData, audioFileURL, waveform, startOffsetInSamples, lengthInSamples
    }
    
    init(id: UUID = UUID(), audioItem: AudioItem, name: String, 
         startPositionInBeats: Double, durationInBeats: Double,
         audioFileURL: URL? = nil, color: Color? = nil, originalDuration: Double? = nil,
         waveform: Waveform? = nil,
         startOffsetInSamples: Int64? = nil, lengthInSamples: Int64? = nil) {
        self.id = id
        self.audioItem = audioItem
        self.name = name
        self.startPositionInBeats = startPositionInBeats
        self.durationInBeats = durationInBeats
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
        
        // Initialize the sample window to the full audio if not specified
        self.startOffsetInSamples = startOffsetInSamples ?? 0
        self.lengthInSamples = lengthInSamples ?? audioItem.lengthInSamples
    }
    
    // Custom initializer from decoder
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        audioItem = try container.decode(AudioItem.self, forKey: .audioItem)
        name = try container.decode(String.self, forKey: .name)
        startPositionInBeats = try container.decode(Double.self, forKey: .startPositionInBeats)
        durationInBeats = try container.decode(Double.self, forKey: .durationInBeats)
        originalDuration = try container.decodeIfPresent(Double.self, forKey: .originalDuration)
        audioFileURL = try container.decodeIfPresent(URL.self, forKey: .audioFileURL)
        waveform = try container.decodeIfPresent(Waveform.self, forKey: .waveform)
        
        // Decode optional color
        if let colorData = try container.decodeIfPresent(CodableColor.self, forKey: .colorData) {
            color = colorData.color
        } else {
            color = nil
        }
        
        startOffsetInSamples = try container.decode(Int64.self, forKey: .startOffsetInSamples)
        lengthInSamples = try container.decode(Int64.self, forKey: .lengthInSamples)
        
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
        try container.encode(startPositionInBeats, forKey: .startPositionInBeats)
        try container.encode(durationInBeats, forKey: .durationInBeats)
        try container.encodeIfPresent(originalDuration, forKey: .originalDuration)
        try container.encodeIfPresent(audioFileURL, forKey: .audioFileURL)
        try container.encodeIfPresent(waveform, forKey: .waveform)
        try container.encode(startOffsetInSamples, forKey: .startOffsetInSamples)
        try container.encode(lengthInSamples, forKey: .lengthInSamples)
        
        // Encode optional color
        if let clipColor = color {
            try container.encode(CodableColor(color: clipColor), forKey: .colorData)
        }
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
    static func create(audioItem: AudioItem, name: String, 
                       startPositionInBeats: Double, durationInBeats: Double, 
                       audioFileURL: URL? = nil, color: Color? = nil, 
                       originalDuration: Double? = nil, waveform: Waveform? = nil, 
                       startOffsetInSamples: Int64? = nil, lengthInSamples: Int64? = nil) -> AudioClip {
        return AudioClip(
            audioItem: audioItem,
            name: name,
            startPositionInBeats: startPositionInBeats,
            durationInBeats: durationInBeats,
            audioFileURL: audioFileURL,
            color: color,
            originalDuration: originalDuration,
            waveform: waveform,
            startOffsetInSamples: startOffsetInSamples,
            lengthInSamples: lengthInSamples
        )
    }
    
    // Create an empty audio clip (for UI testing or placeholders)
    static func createEmpty(audioItem: AudioItem, name: String, startPositionInBeats: Double, durationInBeats: Double, color: Color? = nil, waveform: Waveform? = nil) -> AudioClip {
        return AudioClip(
            audioItem: audioItem,
            name: name,
            startPositionInBeats: startPositionInBeats,
            durationInBeats: durationInBeats,
            color: color,
            waveform: waveform,
            startOffsetInSamples: 0,
            lengthInSamples: audioItem.lengthInSamples
        )
    }
    
    // Implement Equatable to help with updates
    static func == (lhs: AudioClip, rhs: AudioClip) -> Bool {
        return lhs.id == rhs.id &&
               lhs.audioItem.id == rhs.audioItem.id &&
               lhs.name == rhs.name &&
               lhs.startPositionInBeats == rhs.startPositionInBeats &&
               lhs.durationInBeats == rhs.durationInBeats &&
               lhs.originalDuration == rhs.originalDuration &&
               lhs.audioFileURL == rhs.audioFileURL &&
               lhs.waveform?.id == rhs.waveform?.id &&
               lhs.startOffsetInSamples == rhs.startOffsetInSamples &&
               lhs.lengthInSamples == rhs.lengthInSamples
    }
} 
