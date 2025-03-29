import Foundation
import SwiftUI
import AVFoundation

/// Represents a full audio file that has been imported into the application.
/// AudioClips can reference this item and represent windows/segments of the original audio.
struct AudioItem: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var audioFileURL: URL
    var durationInSeconds: Double // Duration in seconds
    var sampleRate: Double
    var numberOfChannels: Int
    var bitDepth: Int
    var fileFormat: String // e.g., "wav", "mp3", "aiff"
    var dateAdded: Date
    var monoWaveform: Waveform? // Mono waveform data for the entire audio file (legacy or mono files)
    var leftWaveform: Waveform? // Left channel waveform data for stereo files
    var rightWaveform: Waveform? // Right channel waveform data for stereo files
    var metadata: [String: String] // Store any additional metadata from the audio file
    var lengthInSamples: Int64 // Total number of samples in the audio file
    
    // Coding keys for Codable
    enum CodingKeys: String, CodingKey {
        case id, name, audioFileURL, durationInSeconds, sampleRate, numberOfChannels
        case bitDepth, fileFormat, dateAdded, monoWaveform, leftWaveform, rightWaveform, metadata, lengthInSamples
        
        // Legacy key for backward compatibility
        case waveform
    }
    
    init(id: UUID = UUID(),
         name: String,
         audioFileURL: URL,
         durationInSeconds: Double,
         sampleRate: Double,
         numberOfChannels: Int,
         bitDepth: Int,
         fileFormat: String,
         monoWaveform: Waveform? = nil,
         leftWaveform: Waveform? = nil,
         rightWaveform: Waveform? = nil,
         metadata: [String: String] = [:],
         lengthInSamples: Int64 = 0,
         clips: [UUID] = []) {
        self.id = id
        self.name = name
        self.audioFileURL = audioFileURL
        self.durationInSeconds = durationInSeconds
        self.sampleRate = sampleRate
        self.numberOfChannels = numberOfChannels
        self.bitDepth = bitDepth
        self.fileFormat = fileFormat
        self.dateAdded = Date()
        self.monoWaveform = monoWaveform
        self.leftWaveform = leftWaveform
        self.rightWaveform = rightWaveform
        self.metadata = metadata
        self.lengthInSamples = lengthInSamples
    }
    
    // Custom decoder for backward compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        audioFileURL = try container.decode(URL.self, forKey: .audioFileURL)
        durationInSeconds = try container.decode(Double.self, forKey: .durationInSeconds)
        sampleRate = try container.decode(Double.self, forKey: .sampleRate)
        numberOfChannels = try container.decode(Int.self, forKey: .numberOfChannels)
        bitDepth = try container.decode(Int.self, forKey: .bitDepth)
        fileFormat = try container.decode(String.self, forKey: .fileFormat)
        dateAdded = try container.decode(Date.self, forKey: .dateAdded)
        metadata = try container.decode([String: String].self, forKey: .metadata)
        lengthInSamples = try container.decode(Int64.self, forKey: .lengthInSamples)
        
        // Handle waveform data with backward compatibility
        if let legacyWaveform = try container.decodeIfPresent(Waveform.self, forKey: .waveform) {
            // If we have a legacy waveform, use it as monoWaveform
            self.monoWaveform = legacyWaveform
            self.leftWaveform = nil
            self.rightWaveform = nil
        } else {
            // Try to decode the new waveform properties
            self.monoWaveform = try container.decodeIfPresent(Waveform.self, forKey: .monoWaveform)
            self.leftWaveform = try container.decodeIfPresent(Waveform.self, forKey: .leftWaveform)
            self.rightWaveform = try container.decodeIfPresent(Waveform.self, forKey: .rightWaveform)
        }
    }
    
    // Custom encoder
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(audioFileURL, forKey: .audioFileURL)
        try container.encode(durationInSeconds, forKey: .durationInSeconds)
        try container.encode(sampleRate, forKey: .sampleRate)
        try container.encode(numberOfChannels, forKey: .numberOfChannels)
        try container.encode(bitDepth, forKey: .bitDepth)
        try container.encode(fileFormat, forKey: .fileFormat)
        try container.encode(dateAdded, forKey: .dateAdded)
        try container.encode(metadata, forKey: .metadata)
        try container.encode(lengthInSamples, forKey: .lengthInSamples)
        
        // Encode waveform data
        try container.encodeIfPresent(monoWaveform, forKey: .monoWaveform)
        try container.encodeIfPresent(leftWaveform, forKey: .leftWaveform)
        try container.encodeIfPresent(rightWaveform, forKey: .rightWaveform)
    }
    
    // Check if the audio file exists
    var fileExists: Bool {
        FileManager.default.fileExists(atPath: audioFileURL.path)
    }
    
    // Get formatted duration string
    var formattedDuration: String {
        let minutes = Int(durationInSeconds) / 60
        let seconds = Int(durationInSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // Helper property to determine if audio is stereo
    var isStereo: Bool {
        return numberOfChannels >= 2
    }
    
    // Backward compatibility property to get the appropriate waveform
    var waveform: Waveform? {
        if isStereo {
            return monoWaveform // Return the combined waveform for stereo files
        } else {
            return monoWaveform // For mono files, return the mono waveform
        }
    }
}

// Custom errors for AudioItem operations
enum AudioItemError: Error {
    case invalidAudioFormat
    case fileNotFound
    case unsupportedFormat
}

// Implement Equatable
extension AudioItem {
    static func == (lhs: AudioItem, rhs: AudioItem) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.audioFileURL == rhs.audioFileURL &&
               lhs.durationInSeconds == rhs.durationInSeconds &&
               lhs.sampleRate == rhs.sampleRate &&
               lhs.numberOfChannels == rhs.numberOfChannels &&
               lhs.bitDepth == rhs.bitDepth &&
               lhs.fileFormat == rhs.fileFormat &&
               lhs.dateAdded == rhs.dateAdded &&
               lhs.metadata == rhs.metadata &&
               lhs.lengthInSamples == rhs.lengthInSamples
    }
}
