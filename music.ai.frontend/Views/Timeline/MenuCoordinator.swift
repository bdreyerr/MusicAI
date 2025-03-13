import SwiftUI
import AppKit

/// Coordinator class to handle menu actions for the timeline
class MenuCoordinator: NSObject, ObservableObject {
    weak var projectViewModel: ProjectViewModel?
    
    @objc func addAudioTrack() {
        projectViewModel?.addTrack(name: "Audio \(projectViewModel?.tracks.count ?? 0 + 1)", type: .audio)
    }
    
    @objc func addMidiTrack() {
        projectViewModel?.addTrack(name: "MIDI \(projectViewModel?.tracks.count ?? 0 + 1)", type: .midi)
    }
} 