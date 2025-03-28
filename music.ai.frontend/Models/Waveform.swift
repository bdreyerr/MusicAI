import Foundation
import SwiftUI

/// Represents a waveform visualization for an audio file
struct Waveform: Identifiable, Equatable, Codable {
    let id: UUID
    var audioFileURL: URL? // URL to the audio file being visualized
    var samples: [Float]? // Audio sample data for waveform rendering
    var sampleRate: Double? // Sample rate of the audio file
    var channelCount: Int? // Number of audio channels
    
    // Waveform appearance properties
    var strokeWidth: CGFloat = 1.0 // Width of the waveform line
    var stripeSpacing: CGFloat = 1.0 // Spacing between stripes in the striped pattern
    var stripeWidth: CGFloat = 1.0 // Width of each stripe
    var color: Color? // Primary color for the waveform
    var secondaryColor: Color? // Secondary color for the striped pattern
    var baseline: Float = 0 // Position of the baseline (usually 0)
    var zoom: CGFloat = 1.0 // Zoom level for the waveform
    
    // Caching properties
    var isCached: Bool = false // Whether the sample data is cached
    var lastRenderWidth: CGFloat? // Last width at which the waveform was rendered
    
    // Coding keys for Codable
    enum CodingKeys: String, CodingKey {
        case id, audioFileURL, samples, sampleRate, channelCount
        case strokeWidth, stripeSpacing, stripeWidth, baseline, zoom
        case colorData, secondaryColorData, isCached, lastRenderWidth
    }
    
    init(id: UUID = UUID(), audioFileURL: URL? = nil, samples: [Float]? = nil,
         sampleRate: Double? = nil, channelCount: Int? = nil,
         strokeWidth: CGFloat = 1.0, stripeSpacing: CGFloat = 1.0, stripeWidth: CGFloat = 1.0,
         color: Color? = nil, secondaryColor: Color? = nil, baseline: Float = 0,
         zoom: CGFloat = 1.0, isCached: Bool = false, lastRenderWidth: CGFloat? = nil) {
        self.id = id
        self.audioFileURL = audioFileURL
        self.samples = samples
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.strokeWidth = strokeWidth
        self.stripeSpacing = stripeSpacing
        self.stripeWidth = stripeWidth
        self.color = color
        self.secondaryColor = secondaryColor
        self.baseline = baseline
        self.zoom = zoom
        self.isCached = isCached
        self.lastRenderWidth = lastRenderWidth
    }
    
    // Custom initializer from decoder
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        audioFileURL = try container.decodeIfPresent(URL.self, forKey: .audioFileURL)
//        samples = try container.decodeIfPresent([Float].self, forKey: .samples)
        sampleRate = try container.decodeIfPresent(Double.self, forKey: .sampleRate)
        channelCount = try container.decodeIfPresent(Int.self, forKey: .channelCount)
        
        strokeWidth = try container.decode(CGFloat.self, forKey: .strokeWidth)
        stripeSpacing = try container.decode(CGFloat.self, forKey: .stripeSpacing)
        stripeWidth = try container.decode(CGFloat.self, forKey: .stripeWidth)
        baseline = try container.decode(Float.self, forKey: .baseline)
        zoom = try container.decode(CGFloat.self, forKey: .zoom)
        isCached = try container.decode(Bool.self, forKey: .isCached)
        
        // Decode optional colors
        if let colorData = try container.decodeIfPresent(CodableColor.self, forKey: .colorData) {
            color = colorData.color
        } else {
            color = nil
        }
        
        if let secondaryColorData = try container.decodeIfPresent(CodableColor.self, forKey: .secondaryColorData) {
            secondaryColor = secondaryColorData.color
        } else {
            secondaryColor = nil
        }
        
        
        // Decode optional customColor
        if let sampleData = try container.decodeIfPresent([Float].self, forKey: .samples) {
            samples = sampleData
        } else {
            samples = nil
        }
        
        if let lastRenderWidthData = try container.decodeIfPresent(CGFloat.self, forKey: .lastRenderWidth) {
            lastRenderWidth = lastRenderWidthData
        } else {
            lastRenderWidth = nil
        }
    }
    
    // Custom encoder
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(audioFileURL, forKey: .audioFileURL)
        try container.encodeIfPresent(samples, forKey: .samples)
        try container.encodeIfPresent(sampleRate, forKey: .sampleRate)
        try container.encodeIfPresent(channelCount, forKey: .channelCount)
        
        try container.encode(strokeWidth, forKey: .strokeWidth)
        try container.encode(stripeSpacing, forKey: .stripeSpacing)
        try container.encode(stripeWidth, forKey: .stripeWidth)
        try container.encode(baseline, forKey: .baseline)
        try container.encode(zoom, forKey: .zoom)
        try container.encode(isCached, forKey: .isCached)
        
        // Encode optional colors
        if let waveformColor = color {
            try container.encode(CodableColor(color: waveformColor), forKey: .colorData)
        }
        
        if let waveformSecondaryColor = secondaryColor {
            try container.encode(CodableColor(color: waveformSecondaryColor), forKey: .secondaryColorData)
        }
        
        // We don't encode the samples array or lastRenderWidth as they're regenerated on load
    }
    
    // Check if the audio file exists
    var fileExists: Bool {
        if let audioFileURL {
            return FileManager.default.fileExists(atPath: audioFileURL.path)
        } else {
            return false
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
    
    // Create a new waveform with audio file URL
    static func create(audioFileURL: URL, color: Color? = nil) -> Waveform {
        return Waveform(audioFileURL: audioFileURL, color: color, secondaryColor: color)
    }
    
    // Create an empty waveform (for UI testing or placeholders)
    static func createEmpty(color: Color? = nil) -> Waveform {
        return Waveform(color: color, secondaryColor: color)
    }
    
    /// Creates a new waveform with updated colors while keeping all other properties the same
    /// - Parameters:
    ///   - primaryColor: The primary color for the waveform
    /// - Returns: A new Waveform instance with updated colors
    func withColors(primaryColor: Color) -> Waveform {
        return Waveform(
            id: self.id,
            audioFileURL: self.audioFileURL,
            samples: self.samples,
            sampleRate: self.sampleRate,
            channelCount: self.channelCount,
            strokeWidth: self.strokeWidth,
            stripeSpacing: self.stripeSpacing,
            stripeWidth: self.stripeWidth,
            color: primaryColor,
            secondaryColor: primaryColor,
            baseline: self.baseline,
            zoom: self.zoom,
            isCached: self.isCached
        )
    }
    
    // Implement Equatable to help with updates
    static func == (lhs: Waveform, rhs: Waveform) -> Bool {
        return lhs.id == rhs.id &&
               lhs.audioFileURL == rhs.audioFileURL &&
               lhs.sampleRate == rhs.sampleRate &&
               lhs.channelCount == rhs.channelCount &&
               lhs.strokeWidth == rhs.strokeWidth &&
               lhs.stripeSpacing == rhs.stripeSpacing &&
               lhs.stripeWidth == rhs.stripeWidth &&
               lhs.baseline == rhs.baseline &&
               lhs.zoom == rhs.zoom
    }
} 
