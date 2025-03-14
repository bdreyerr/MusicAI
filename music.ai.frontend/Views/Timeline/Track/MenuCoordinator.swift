import SwiftUI
import AppKit

/// Coordinator class to handle menu actions for the timeline
class MenuCoordinator: NSObject, ObservableObject {
    weak var projectViewModel: ProjectViewModel?
    var defaultTrackHeight: CGFloat = 70 // Default track height
    
    @objc func addAudioTrack() {
        projectViewModel?.addTrack(name: "Audio \(projectViewModel?.tracks.count ?? 0 + 1)", type: .audio, height: defaultTrackHeight)
    }
    
    @objc func addMidiTrack() {
        projectViewModel?.addTrack(name: "MIDI \(projectViewModel?.tracks.count ?? 0 + 1)", type: .midi, height: defaultTrackHeight)
    }
} 