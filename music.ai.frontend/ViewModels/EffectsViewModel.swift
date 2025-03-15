import SwiftUI
import Combine

/// EffectsViewModel handles all effects-related operations and state management
class EffectsViewModel: ObservableObject {
    // Reference to the project view model for accessing tracks and other project data
    private weak var projectViewModel: ProjectViewModel?
    
    // Initialize with project view model
    init(projectViewModel: ProjectViewModel) {
        self.projectViewModel = projectViewModel
    }
    
    // MARK: - Effects Management
    
    /// Add an effect to the selected track
    func addEffectToSelectedTrack(_ effect: Effect) {
        guard let projectViewModel = projectViewModel,
              let trackId = projectViewModel.selectedTrackId,
              let index = projectViewModel.tracks.firstIndex(where: { $0.id == trackId }) else { return }
        
        var updatedTrack = projectViewModel.tracks[index]
        updatedTrack.addEffect(effect)
        
        // Update the track in the project view model
        projectViewModel.updateTrack(at: index, with: updatedTrack)
    }
    
    /// Remove an effect from the selected track
    func removeEffectFromSelectedTrack(effectId: UUID) {
        guard let projectViewModel = projectViewModel,
              let trackId = projectViewModel.selectedTrackId,
              let index = projectViewModel.tracks.firstIndex(where: { $0.id == trackId }) else { return }
        
        var updatedTrack = projectViewModel.tracks[index]
        updatedTrack.removeEffect(id: effectId)
        
        // Update the track in the project view model
        projectViewModel.updateTrack(at: index, with: updatedTrack)
    }
    
    /// Update an effect on the selected track
    func updateEffectOnSelectedTrack(_ updatedEffect: Effect) {
        guard let projectViewModel = projectViewModel,
              let trackId = projectViewModel.selectedTrackId,
              let trackIndex = projectViewModel.tracks.firstIndex(where: { $0.id == trackId }) else { return }
        
        var updatedTrack = projectViewModel.tracks[trackIndex]
        
        // Find and update the effect
        if let effectIndex = updatedTrack.effects.firstIndex(where: { $0.id == updatedEffect.id }) {
            updatedTrack.effects[effectIndex] = updatedEffect
            
            // Update the track in the project view model
            projectViewModel.updateTrack(at: trackIndex, with: updatedTrack)
        }
    }
    
    /// Set the instrument for the selected track (only applicable for MIDI tracks)
    func setInstrumentForSelectedTrack(_ instrument: Effect?) {
        guard let projectViewModel = projectViewModel,
              let trackId = projectViewModel.selectedTrackId,
              let index = projectViewModel.tracks.firstIndex(where: { $0.id == trackId }) else { return }
        
        var updatedTrack = projectViewModel.tracks[index]
        updatedTrack.setInstrument(instrument)
        
        // Update the track in the project view model
        projectViewModel.updateTrack(at: index, with: updatedTrack)
    }
    
    /// Get compatible effect types for the selected track
    func compatibleEffectTypesForSelectedTrack() -> [EffectType] {
        guard let projectViewModel = projectViewModel,
              let track = projectViewModel.selectedTrack else { return [] }
        
        switch track.type {
        case .audio:
            return [.equalizer, .compressor, .reverb, .delay, .filter]
        case .midi:
            return [.arpeggiator, .chordTrigger, .instrument]
        case .instrument:
            return [.filter, .synthesizer, .reverb, .delay]
        }
    }
    
    /// Get all effects for a specific track
    func effectsForTrack(trackId: UUID) -> [Effect] {
        guard let projectViewModel = projectViewModel,
              let track = projectViewModel.tracks.first(where: { $0.id == trackId }) else {
            return []
        }
        
        return track.effects
    }
    
    /// Get the instrument for a specific track (if any)
    func instrumentForTrack(trackId: UUID) -> Effect? {
        guard let projectViewModel = projectViewModel,
              let track = projectViewModel.tracks.first(where: { $0.id == trackId }) else {
            return nil
        }
        
        return track.instrument
    }
    
    /// Check if a track has an instrument
    func trackHasInstrument(trackId: UUID) -> Bool {
        return instrumentForTrack(trackId: trackId) != nil
    }
    
    /// Create a default instrument for a track
    func createDefaultInstrumentForTrack(trackId: UUID) -> Bool {
        guard let projectViewModel = projectViewModel,
              let trackIndex = projectViewModel.tracks.firstIndex(where: { $0.id == trackId }) else {
            return false
        }
        
        var track = projectViewModel.tracks[trackIndex]
        
        // Only applicable for MIDI tracks
        guard track.type == .midi else {
            return false
        }
        
        // Create a default piano instrument
        let pianoInstrument = Effect(type: .instrument, name: "Grand Piano")
        track.setInstrument(pianoInstrument)
        
        // Update the track in the project view model
        projectViewModel.updateTrack(at: trackIndex, with: track)
        
        return true
    }
} 