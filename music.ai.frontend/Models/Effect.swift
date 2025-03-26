import Foundation
import SwiftUI

/// Represents the type of effect or instrument
enum EffectType: Equatable, Codable {
    case equalizer
    case compressor
    case reverb
    case delay
    case filter
    case arpeggiator
    case chordTrigger
    case synthesizer
    case instrument
    case other(String)
    
    // Codable implementation
    enum CodingKeys: String, CodingKey {
        case type
        case customName
    }
    
    enum EffectTypeCase: String, Codable {
        case equalizer
        case compressor
        case reverb
        case delay
        case filter
        case arpeggiator
        case chordTrigger
        case synthesizer
        case instrument
        case other
    }
    
    // Custom encoder
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .equalizer:
            try container.encode(EffectTypeCase.equalizer, forKey: .type)
        case .compressor:
            try container.encode(EffectTypeCase.compressor, forKey: .type)
        case .reverb:
            try container.encode(EffectTypeCase.reverb, forKey: .type)
        case .delay:
            try container.encode(EffectTypeCase.delay, forKey: .type)
        case .filter:
            try container.encode(EffectTypeCase.filter, forKey: .type)
        case .arpeggiator:
            try container.encode(EffectTypeCase.arpeggiator, forKey: .type)
        case .chordTrigger:
            try container.encode(EffectTypeCase.chordTrigger, forKey: .type)
        case .synthesizer:
            try container.encode(EffectTypeCase.synthesizer, forKey: .type)
        case .instrument:
            try container.encode(EffectTypeCase.instrument, forKey: .type)
        case .other(let name):
            try container.encode(EffectTypeCase.other, forKey: .type)
            try container.encode(name, forKey: .customName)
        }
    }
    
    // Custom decoder
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeCase = try container.decode(EffectTypeCase.self, forKey: .type)
        
        switch typeCase {
        case .equalizer:
            self = .equalizer
        case .compressor:
            self = .compressor
        case .reverb:
            self = .reverb
        case .delay:
            self = .delay
        case .filter:
            self = .filter
        case .arpeggiator:
            self = .arpeggiator
        case .chordTrigger:
            self = .chordTrigger
        case .synthesizer:
            self = .synthesizer
        case .instrument:
            self = .instrument
        case .other:
            let name = try container.decode(String.self, forKey: .customName)
            self = .other(name)
        }
    }
    
    var name: String {
        switch self {
        case .equalizer:
            return "EQ"
        case .compressor:
            return "Compressor"
        case .reverb:
            return "Reverb"
        case .delay:
            return "Delay"
        case .filter:
            return "Filter"
        case .arpeggiator:
            return "Arpeggiator"
        case .chordTrigger:
            return "Chord Trigger"
        case .synthesizer:
            return "Synthesizer"
        case .instrument:
            return "Instrument"
        case .other(let name):
            return name
        }
    }
    
    var icon: String {
        switch self {
        case .equalizer:
            return "waveform.path.ecg"
        case .compressor:
            return "waveform.path"
        case .reverb:
            return "speaker.wave.3"
        case .delay:
            return "clock"
        case .filter:
            return "slider.horizontal.3"
        case .arpeggiator:
            return "pianokeys"
        case .chordTrigger:
            return "music.note.list"
        case .synthesizer:
            return "waveform.path.badge.plus"
        case .instrument:
            return "music.note"
        case .other:
            return "square.stack.3d.up"
        }
    }
    
    /// Returns true if this effect is compatible with the given track type
    func isCompatibleWith(trackType: TrackType) -> Bool {
        switch self {
        case .equalizer, .compressor, .reverb, .delay:
            // Audio effects work with audio tracks and master track
            return trackType == .audio || trackType == .master
        case .filter:
            // Filter works with audio, instrument, and master tracks
            return trackType == .audio || trackType == .instrument || trackType == .master
        case .arpeggiator, .chordTrigger:
            // MIDI effects work with MIDI tracks
            return trackType == .midi
        case .synthesizer:
            // Synthesizer works with instrument tracks
            return trackType == .instrument
        case .instrument:
            // Instruments work with MIDI tracks
            return trackType == .midi
        case .other:
            // Other effects might work with any track type
            return true
        }
    }
}

/// Represents an effect or instrument that can be applied to a track
struct Effect: Identifiable, Equatable, Codable {
    let id: UUID
    var type: EffectType
    var name: String
    var isEnabled: Bool = true
    var parameters: [String: Double] = [:]
    
    init(id: UUID = UUID(), type: EffectType, name: String? = nil, isEnabled: Bool = true) {
        self.id = id
        self.type = type
        self.name = name ?? type.name
        self.isEnabled = isEnabled
        
        // Initialize with default parameters based on effect type
        switch type {
        case .equalizer:
            parameters = [
                "lowGain": 0.0,
                "midGain": 0.0,
                "highGain": 0.0
            ]
        case .compressor:
            parameters = [
                "threshold": -20.0,
                "ratio": 4.0,
                "attack": 5.0,
                "release": 50.0
            ]
        case .reverb:
            parameters = [
                "size": 0.5,
                "mix": 0.3
            ]
        case .delay:
            parameters = [
                "time": 0.5,
                "feedback": 0.3,
                "mix": 0.3
            ]
        case .filter:
            parameters = [
                "cutoff": 1000.0,
                "resonance": 0.5
            ]
        default:
            // Other effects might have their own parameters
            parameters = [:]
        }
    }
    
    // Implement Equatable for Effect
    static func == (lhs: Effect, rhs: Effect) -> Bool {
        return lhs.id == rhs.id &&
               lhs.type == rhs.type &&
               lhs.name == rhs.name &&
               lhs.isEnabled == rhs.isEnabled
    }
}

// Extension to create sample effects for preview
extension Effect {
    static var samples: [Effect] = [
        Effect(type: .equalizer),
        Effect(type: .compressor),
        Effect(type: .reverb),
        Effect(type: .delay),
        Effect(type: .filter),
        Effect(type: .arpeggiator),
        Effect(type: .chordTrigger),
        Effect(type: .synthesizer),
        Effect(type: .instrument, name: "Piano")
    ]
} 
