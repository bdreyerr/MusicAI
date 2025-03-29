import Foundation
import SwiftUI
//import Models.CodableUtilities

enum TrackType: String, Equatable, Codable {
    case audio
    case midi
    case instrument
    case master // New case for master track
    
    var icon: String {
        switch self {
        case .audio:
            return "waveform"
        case .midi:
            return "pianokeys"
        case .instrument:
            return "music.note"
        case .master:
            return "slider.horizontal.3" // Icon representing a mixer
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
        case .master:
            return Color.red.opacity(0.8) // Distinctive color for master track
        }
    }
    
    // Get a background color that works well with the current theme
    func backgroundColor(for theme: ThemeOption) -> Color {
        let baseColor = self.color
        
        switch theme {
        case .light:
            return baseColor.opacity(0.1)
        case .lightGrey:
            return baseColor.opacity(0.15)
        case .dark:
            return baseColor.opacity(0.2)
        case .black:
            return baseColor.opacity(0.25)
        }
    }
}

struct Track: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var type: TrackType
    var isMuted: Bool = false
    var isSolo: Bool = false
    var isArmed: Bool = false
    var isEnabled: Bool = true // Whether the track is enabled for playback
    var volume: Double = 0.5 // 0.0 to 1.0 (50% by default)
    var pan: Double = 0.5 // 0.0 (left) to 1.0 (right), 0.5 is center
    var height: CGFloat = 100 // Default track height
    var isCollapsed: Bool = false // Whether the track is collapsed (minimized)
    var customColor: Color? = nil // Custom color for the track, overrides the default type color
    var effects: [Effect] = [] // List of effects applied to this track
    var instrument: Effect? = nil // Optional instrument for MIDI tracks
    var midiClips: [MidiClip] = [] // MIDI clips on this track
    var audioClips: [AudioClip] = [] // Audio clips on this track
    
    // Coding keys for Codable
    enum CodingKeys: String, CodingKey {
        case id, name, type, isMuted, isSolo, isArmed, isEnabled, volume, pan, height, isCollapsed
        case customColorData, effects, instrument, midiClips, audioClips
    }
    
    init(id: UUID = UUID(), name: String, type: TrackType, isMuted: Bool = false, isSolo: Bool = false, isArmed: Bool = false, 
         isEnabled: Bool = true, volume: Double = 0.5, pan: Double = 0.5, height: CGFloat = 100, isCollapsed: Bool = false,
         customColor: Color? = nil, effects: [Effect] = [], instrument: Effect? = nil, midiClips: [MidiClip] = [], audioClips: [AudioClip] = []) {
        self.id = id
        self.name = name
        self.type = type
        self.isMuted = isMuted
        self.isSolo = isSolo
        self.isArmed = isArmed
        self.isEnabled = isEnabled
        self.volume = volume
        self.pan = pan
        self.height = height
        self.isCollapsed = isCollapsed
        self.customColor = customColor
        self.effects = effects
        self.instrument = instrument
        self.midiClips = midiClips
        self.audioClips = audioClips
    }
    
    // Custom initializer from decoder
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(TrackType.self, forKey: .type)
        isMuted = try container.decode(Bool.self, forKey: .isMuted)
        isSolo = try container.decode(Bool.self, forKey: .isSolo)
        isArmed = try container.decode(Bool.self, forKey: .isArmed)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        volume = try container.decode(Double.self, forKey: .volume)
        pan = try container.decode(Double.self, forKey: .pan)
        height = try container.decode(CGFloat.self, forKey: .height)
        isCollapsed = try container.decode(Bool.self, forKey: .isCollapsed)
        
        // Decode optional customColor
        if let colorData = try container.decodeIfPresent(CodableColor.self, forKey: .customColorData) {
            customColor = colorData.color
        } else {
            customColor = nil
        }
        
        effects = try container.decode([Effect].self, forKey: .effects)
        instrument = try container.decodeIfPresent(Effect.self, forKey: .instrument)
        midiClips = try container.decode([MidiClip].self, forKey: .midiClips)
        audioClips = try container.decode([AudioClip].self, forKey: .audioClips)
    }
    
    // Custom encoder
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(isMuted, forKey: .isMuted)
        try container.encode(isSolo, forKey: .isSolo)
        try container.encode(isArmed, forKey: .isArmed)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(volume, forKey: .volume)
        try container.encode(pan, forKey: .pan)
        try container.encode(height, forKey: .height)
        try container.encode(isCollapsed, forKey: .isCollapsed)
        
        // Encode optional customColor
        if let color = customColor {
            try container.encode(CodableColor(color: color), forKey: .customColorData)
        }
        
        try container.encode(effects, forKey: .effects)
        try container.encode(instrument, forKey: .instrument)
        try container.encode(midiClips, forKey: .midiClips)
        try container.encode(audioClips, forKey: .audioClips)
    }
    
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
        case .lightGrey:
            return baseColor.opacity(0.15)
        case .dark:
            return baseColor.opacity(0.2)
        case .black:
            return baseColor.opacity(0.25)
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
            print("🎹 TRACK MODEL: Adding MIDI clip \(clip.name) (id: \(clip.id)) at position \(clip.startBeat)")
            midiClips.append(clip)
            print("🎹 TRACK MODEL: MIDI clip added successfully. Total clips: \(midiClips.count)")
            return true
        }
        print("❌ TRACK MODEL: Failed to add MIDI clip - track type is not MIDI")
        return false
    }
    
    // Remove a MIDI clip from the track
    mutating func removeMidiClip(id: UUID) {
        print("🎹 TRACK MODEL: Removing MIDI clip with id: \(id)")
        let countBefore = midiClips.count
        midiClips.removeAll { $0.id == id }
        let countAfter = midiClips.count
        
        if countBefore != countAfter {
            print("🎹 TRACK MODEL: MIDI clip removed successfully. Remaining clips: \(countAfter)")
        } else {
            print("❌ TRACK MODEL: Failed to remove MIDI clip - clip not found")
        }
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
    
    // Check if multiple MIDI clips can be added starting at a position
    func canAddMidiClips(startingAt initialStartBeat: Double, clips: [MidiClip]) -> Bool {
        // Only MIDI tracks can have MIDI clips
        guard type == .midi else { return false }
        
        // For each clip, check if its position would overlap with existing clips
        for clip in clips {
            // Get the start and end positions of this clip
            let startBeat = clip.startBeat
            let endBeat = startBeat + clip.duration
            
            // Check for overlaps with existing clips
            for existingClip in midiClips {
                // If the new clip overlaps with an existing clip, return false
                if (startBeat < existingClip.endBeat && endBeat > existingClip.startBeat) {
                    return false
                }
            }
            
            // Also check for overlaps with other clips being added
            for otherClip in clips where clip.id != otherClip.id {
                let otherStartBeat = otherClip.startBeat
                let otherEndBeat = otherStartBeat + otherClip.duration
                
                // If this clip overlaps with another new clip, return false
                if (startBeat < otherEndBeat && endBeat > otherStartBeat) {
                    return false
                }
            }
        }
        
        return true
    }
    
    // Add an audio clip to the track (only applicable for audio tracks)
    mutating func addAudioClip(_ clip: AudioClip) -> Bool {
        // Only add the clip if this is an audio track
        if type == .audio {
            print("🔊 TRACK MODEL: Adding audio clip \(clip.name) (id: \(clip.id)) at position \(clip.startPositionInBeats)")
            audioClips.append(clip)
            print("🔊 TRACK MODEL: Audio clip added successfully. Total clips: \(audioClips.count)")
            return true
        }
        print("❌ TRACK MODEL: Failed to add audio clip - track type is not audio")
        return false
    }
    
    // Remove an audio clip from the track
    mutating func removeAudioClip(id: UUID) {
        print("🔊 TRACK MODEL: Removing audio clip with id: \(id)")
        let countBefore = audioClips.count
        audioClips.removeAll { $0.id == id }
        let countAfter = audioClips.count
        
        if countBefore != countAfter {
            print("🔊 TRACK MODEL: Audio clip removed successfully. Remaining clips: \(countAfter)")
        } else {
            print("❌ TRACK MODEL: Failed to remove audio clip - clip not found")
        }
    }
    
    // Check if an audio clip can be added at the specified position
    func canAddAudioClip(startBeat: Double, duration: Double) -> Bool {
        // Only audio tracks can have audio clips
        guard type == .audio else { return false }
        
        let endBeat = startBeat + duration
        
        // Check for overlaps with existing clips
        for clip in audioClips {
            // If the new clip overlaps with an existing clip, return false
            if (startBeat < clip.endBeat && endBeat > clip.startPositionInBeats) {
                return false
            }
        }
        
        return true
    }
    
    // Check if multiple audio clips can be added starting at a position
    func canAddAudioClips(startingAt initialStartBeat: Double, clips: [AudioClip]) -> Bool {
        // Only audio tracks can have audio clips
        guard type == .audio else { return false }
        
        // For each clip, check if its position would overlap with existing clips
        for clip in clips {
            // Get the start and end positions of this clip
            let startBeat = clip.startPositionInBeats
            let endBeat = startBeat + clip.durationInBeats
            
            // Check for overlaps with existing clips
            for existingClip in audioClips {
                // If the new clip overlaps with an existing clip, return false
                if (startBeat < existingClip.endBeat && endBeat > existingClip.startPositionInBeats) {
                    return false
                }
            }
            
            // Also check for overlaps with other clips being added
            for otherClip in clips where clip.id != otherClip.id {
                let otherStartBeat = otherClip.startPositionInBeats
                let otherEndBeat = otherStartBeat + otherClip.durationInBeats
                
                // If this clip overlaps with another new clip, return false
                if (startBeat < otherEndBeat && endBeat > otherStartBeat) {
                    return false
                }
            }
        }
        
        return true
    }
    
    // MARK: - Equatable
    
    static func == (lhs: Track, rhs: Track) -> Bool {
        // Compare the basic properties
        guard lhs.id == rhs.id &&
              lhs.name == rhs.name &&
              lhs.type == rhs.type &&
              lhs.isMuted == rhs.isMuted &&
              lhs.isSolo == rhs.isSolo &&
              lhs.isArmed == rhs.isArmed &&
              lhs.isEnabled == rhs.isEnabled &&
              lhs.volume == rhs.volume &&
              lhs.pan == rhs.pan &&
              lhs.height == rhs.height &&
              lhs.isCollapsed == rhs.isCollapsed &&
              lhs.midiClips.count == rhs.midiClips.count &&
              lhs.audioClips.count == rhs.audioClips.count else {
            return false
        }
        
        // Compare the MIDI clips
        for (index, lhsClip) in lhs.midiClips.enumerated() {
            let rhsClip = rhs.midiClips[index]
            if lhsClip.id != rhsClip.id ||
               lhsClip.startBeat != rhsClip.startBeat ||
               lhsClip.duration != rhsClip.duration {
                return false
            }
        }
        
        // Compare the audio clips
        for (index, lhsClip) in lhs.audioClips.enumerated() {
            let rhsClip = rhs.audioClips[index]
            if lhsClip.id != rhsClip.id ||
               lhsClip.startPositionInBeats != rhsClip.startPositionInBeats ||
               lhsClip.durationInBeats != rhsClip.durationInBeats {
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
