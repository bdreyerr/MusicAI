import Foundation
import SwiftUI

enum TrackType {
    case audio
    case midi
    case instrument
    
    var icon: String {
        switch self {
        case .audio:
            return "waveform"
        case .midi:
            return "pianokeys"
        case .instrument:
            return "music.note"
        }
    }
    
    var color: Color {
        switch self {
        case .audio:
            return Color.blue.opacity(0.8)
        case .midi:
            return Color.green.opacity(0.8)
        case .instrument:
            return Color.purple.opacity(0.8)
        }
    }
    
    // Get a background color that works well with the current theme
    func backgroundColor(for theme: ThemeOption) -> Color {
        let baseColor = self.color
        
        switch theme {
        case .light:
            return baseColor.opacity(0.1)
        case .dark:
            return baseColor.opacity(0.2)
        }
    }
}

struct Track: Identifiable {
    let id = UUID()
    var name: String
    var type: TrackType
    var isMuted: Bool = false
    var isSolo: Bool = false
    var isArmed: Bool = false
    var isEnabled: Bool = true // Whether the track is enabled for playback
    var volume: Double = 0.8 // 0.0 to 1.0
    var pan: Double = 0.5 // 0.0 (left) to 1.0 (right), 0.5 is center
    var height: CGFloat = 70 // Default track height
    var customColor: Color? = nil // Custom color for the track, overrides the default type color
    var effects: [Effect] = [] // List of effects applied to this track
    var instrument: Effect? = nil // Optional instrument for MIDI tracks
    var midiClips: [MidiClip] = [] // MIDI clips on this track
    
    // Get the effective color for the track (custom color or default type color)
    var effectiveColor: Color {
        return customColor ?? type.color
    }
    
    // Get the effective background color based on the theme
    func effectiveBackgroundColor(for theme: ThemeOption) -> Color {
        let baseColor = effectiveColor
        
        switch theme {
        case .light:
            return baseColor.opacity(0.1)
        case .dark:
            return baseColor.opacity(0.2)
        }
    }
    
    // Add an effect to the track
    mutating func addEffect(_ effect: Effect) {
        // Only add the effect if it's compatible with this track type
        if effect.type.isCompatibleWith(trackType: type) {
            effects.append(effect)
        }
    }
    
    // Remove an effect from the track
    mutating func removeEffect(id: UUID) {
        effects.removeAll { $0.id == id }
    }
    
    // Set the instrument for this track (only applicable for MIDI tracks)
    mutating func setInstrument(_ instrument: Effect?) {
        if type == .midi && instrument?.type == .instrument {
            self.instrument = instrument
        }
    }
    
    // Add a MIDI clip to the track (only applicable for MIDI tracks)
    mutating func addMidiClip(_ clip: MidiClip) -> Bool {
        // Only add the clip if this is a MIDI track
        if type == .midi {
            midiClips.append(clip)
            return true
        }
        return false
    }
    
    // Remove a MIDI clip from the track
    mutating func removeMidiClip(id: UUID) {
        midiClips.removeAll { $0.id == id }
    }
    
    // Check if a MIDI clip can be added at the specified position
    func canAddMidiClip(startBeat: Double, duration: Double) -> Bool {
        // Only MIDI tracks can have MIDI clips
        guard type == .midi else { return false }
        
        let endBeat = startBeat + duration
        
        // Check for overlaps with existing clips
        for clip in midiClips {
            // If the new clip overlaps with an existing clip, return false
            if (startBeat < clip.endBeat && endBeat > clip.startBeat) {
                return false
            }
        }
        
        return true
    }
}

// Extension to create sample tracks for preview
extension Track {
    static var samples: [Track] = [
        createDrumTrack(),
        createBassTrack(),
        createPianoTrack(),
        createSynthLeadTrack(),
        createVocalsTrack()
    ]
    
    // Helper methods to create sample tracks with effects
    private static func createDrumTrack() -> Track {
        var track = Track(name: "Drums", type: .audio)
        track.addEffect(Effect(type: .equalizer))
        track.addEffect(Effect(type: .compressor))
        return track
    }
    
    private static func createBassTrack() -> Track {
        var track = Track(name: "Bass", type: .audio)
        track.addEffect(Effect(type: .equalizer))
        track.addEffect(Effect(type: .compressor))
        return track
    }
    
    private static func createPianoTrack() -> Track {
        var track = Track(name: "Piano", type: .midi)
        track.instrument = Effect(type: .instrument, name: "Grand Piano")
        track.addEffect(Effect(type: .reverb))
        return track
    }
    
    private static func createSynthLeadTrack() -> Track {
        var track = Track(name: "Synth Lead", type: .midi)
        track.instrument = Effect(type: .instrument, name: "Analog Synth")
        track.addEffect(Effect(type: .arpeggiator))
        track.addEffect(Effect(type: .delay))
        return track
    }
    
    private static func createVocalsTrack() -> Track {
        var track = Track(name: "Vocals", type: .audio)
        track.addEffect(Effect(type: .equalizer))
        track.addEffect(Effect(type: .compressor))
        track.addEffect(Effect(type: .reverb))
        return track
    }
} 