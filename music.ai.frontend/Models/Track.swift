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
    var volume: Double = 0.8 // 0.0 to 1.0
    var pan: Double = 0.5 // 0.0 (left) to 1.0 (right), 0.5 is center
    
    // Clips would be stored here in a real implementation
    // var clips: [Clip] = []
}

// Extension to create sample tracks for preview
extension Track {
    static var samples: [Track] = [
        Track(name: "Drums", type: .audio),
        Track(name: "Bass", type: .audio),
        Track(name: "Piano", type: .midi),
        Track(name: "Synth Lead", type: .midi),
        Track(name: "Vocals", type: .audio)
    ]
} 