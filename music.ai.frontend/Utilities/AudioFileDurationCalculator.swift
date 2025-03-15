import Foundation
import AVFoundation

/// Utility class to calculate audio file durations
class AudioFileDurationCalculator {
    
    /// Calculate the duration of an audio file in beats
    /// - Parameters:
    ///   - url: The URL of the audio file
    ///   - tempo: The project tempo in BPM
    /// - Returns: The duration in beats, or a default value if the file couldn't be read
    static func calculateDurationInBeats(url: URL, tempo: Double) -> Double {
        // Create an AVAsset from the file URL
        let asset = AVAsset(url: url)
        
        // Get the duration in seconds
        let durationInSeconds = CMTimeGetSeconds(asset.duration)
        
        // If we couldn't get a valid duration, return a default value
        guard durationInSeconds.isFinite && durationInSeconds > 0 else {
            return 4.0 // Default to 4 beats if we can't determine the duration
        }
        
        // Calculate beats based on tempo (beats per minute)
        // beats = seconds * (beats/minute) / (seconds/minute)
        let durationInBeats = durationInSeconds * (tempo / 60.0)
        
        // Round to the nearest quarter beat for cleaner alignment
        return round(durationInBeats * 4) / 4
    }
} 