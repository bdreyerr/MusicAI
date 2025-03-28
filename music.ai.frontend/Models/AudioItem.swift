import Foundation
import SwiftUI
import AVFoundation

/// Represents a full audio file that has been imported into the application.
/// AudioClips can reference this item and represent windows/segments of the original audio.
struct AudioItem: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var audioFileURL: URL
    var duration: Double // Duration in seconds
    var sampleRate: Double
    var numberOfChannels: Int
    var bitDepth: Int
    var fileFormat: String // e.g., "wav", "mp3", "aiff"
    var dateAdded: Date
    var waveform: Waveform? // Full waveform data for the entire audio file
    var metadata: [String: String] // Store any additional metadata from the audio file
    
    // Coding keys for Codable
    enum CodingKeys: String, CodingKey {
        case id, name, audioFileURL, duration, sampleRate, numberOfChannels
        case bitDepth, fileFormat, dateAdded, waveform, metadata
    }
    
    init(id: UUID = UUID(),
         name: String,
         audioFileURL: URL,
         duration: Double,
         sampleRate: Double,
         numberOfChannels: Int,
         bitDepth: Int,
         fileFormat: String,
         waveform: Waveform? = nil,
         metadata: [String: String] = [:],
         clips: [UUID] = []) {
        self.id = id
        self.name = name
        self.audioFileURL = audioFileURL
        self.duration = duration
        self.sampleRate = sampleRate
        self.numberOfChannels = numberOfChannels
        self.bitDepth = bitDepth
        self.fileFormat = fileFormat
        self.dateAdded = Date()
        self.waveform = waveform
        self.metadata = metadata
    }
    
    
    // Check if the audio file exists
    var fileExists: Bool {
        FileManager.default.fileExists(atPath: audioFileURL.path)
    }
    
    // Get formatted duration string
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
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
               lhs.duration == rhs.duration &&
               lhs.sampleRate == rhs.sampleRate &&
               lhs.numberOfChannels == rhs.numberOfChannels &&
               lhs.bitDepth == rhs.bitDepth &&
               lhs.fileFormat == rhs.fileFormat &&
               lhs.dateAdded == rhs.dateAdded &&
               lhs.metadata == rhs.metadata
    }
}
