import Foundation
import SwiftUI

/// Represents the type of effect or instrument
enum EffectType: Equatable {
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
struct Effect: Identifiable, Equatable {
    let id = UUID()
    var type: EffectType
    var name: String
    var isEnabled: Bool = true
    var parameters: [String: Double] = [:]
    
    init(type: EffectType, name: String? = nil, isEnabled: Bool = true) {
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