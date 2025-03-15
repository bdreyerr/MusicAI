import SwiftUI
import Combine

/// MidiViewModel handles all MIDI-related operations and state management
class MidiViewModel: ObservableObject {
    // Reference to the project view model for accessing tracks and other project data
    private weak var projectViewModel: ProjectViewModel?
    
    // Reference to the timeline state
    private weak var timelineState: TimelineState?
    
    // Initialize with project view model and timeline state
    init(projectViewModel: ProjectViewModel, timelineState: TimelineState? = nil) {
        self.projectViewModel = projectViewModel
        self.timelineState = timelineState
    }
    
    // MARK: - MIDI Clip Management
    
    /// Create a MIDI clip from the current selection
    func createMidiClipFromSelection() -> Bool {
        // Ensure there is an active selection and we have references to required objects
        guard let projectViewModel = projectViewModel,
              let timelineState = findTimelineState(),
              timelineState.selectionActive,
              let trackId = timelineState.selectionTrackId,
              let trackIndex = projectViewModel.tracks.firstIndex(where: { $0.id == trackId }) else {
            return false
        }
        
        // Get the selected track
        var track = projectViewModel.tracks[trackIndex]
        
        // Ensure this is a MIDI track
        guard track.type == .midi else {
            return false
        }
        
        // Get the selection range
        let (startBeat, endBeat) = timelineState.normalizedSelectionRange
        let duration = endBeat - startBeat
        
        // Ensure the duration is valid
        guard duration > 0 else {
            return false
        }
        
        // Check if we can add a clip at this position (no overlaps)
        guard track.canAddMidiClip(startBeat: startBeat, duration: duration) else {
            return false
        }
        
        // Create a new MIDI clip
        let clipName = "Clip \(track.midiClips.count + 1)"
        let newClip = MidiClip.createEmpty(name: clipName, startBeat: startBeat, duration: duration)
        
        // Add the clip to the track
        track.addMidiClip(newClip)
        
        // Update the track in the project view model
        projectViewModel.updateTrack(at: trackIndex, with: track)
        
        // Clear the selection
        timelineState.clearSelection()
        
        return true
    }
    
    /// Remove a MIDI clip from a track
    func removeMidiClip(trackId: UUID, clipId: UUID) -> Bool {
        guard let projectViewModel = projectViewModel,
              let trackIndex = projectViewModel.tracks.firstIndex(where: { $0.id == trackId }) else {
            return false
        }
        
        var track = projectViewModel.tracks[trackIndex]
        
        // Ensure this is a MIDI track
        guard track.type == .midi else {
            return false
        }
        
        // Remove the clip
        track.removeMidiClip(id: clipId)
        
        // Update the track in the project view model
        projectViewModel.updateTrack(at: trackIndex, with: track)
        
        return true
    }
    
    /// Rename a MIDI clip
    func renameMidiClip(trackId: UUID, clipId: UUID, newName: String) -> Bool {
        guard let projectViewModel = projectViewModel,
              !newName.isEmpty,
              let trackIndex = projectViewModel.tracks.firstIndex(where: { $0.id == trackId }) else {
            return false
        }
        
        var track = projectViewModel.tracks[trackIndex]
        
        // Ensure this is a MIDI track
        guard track.type == .midi else {
            return false
        }
        
        // Find the clip in the track
        guard let clipIndex = track.midiClips.firstIndex(where: { $0.id == clipId }) else {
            return false
        }
        
        // Update the clip name
        var updatedClip = track.midiClips[clipIndex]
        updatedClip.name = newName
        track.midiClips[clipIndex] = updatedClip
        
        // Update the track in the project view model
        projectViewModel.updateTrack(at: trackIndex, with: track)
        
        return true
    }
    
    /// Get all MIDI clips for a specific track
    func midiClipsForTrack(trackId: UUID) -> [MidiClip] {
        guard let projectViewModel = projectViewModel,
              let track = projectViewModel.tracks.first(where: { $0.id == trackId }),
              track.type == .midi else {
            return []
        }
        
        return track.midiClips
    }
    
    /// Move a MIDI clip to a new position
    func moveMidiClip(trackId: UUID, clipId: UUID, newStartBeat: Double) -> Bool {
        guard let projectViewModel = projectViewModel,
              let trackIndex = projectViewModel.tracks.firstIndex(where: { $0.id == trackId }) else {
            print("Failed to find track with ID: \(trackId)")
            return false
        }
        
        var track = projectViewModel.tracks[trackIndex]
        
        // Ensure this is a MIDI track
        guard track.type == .midi else {
            print("Track is not a MIDI track")
            return false
        }
        
        // Find the clip in the track
        guard let clipIndex = track.midiClips.firstIndex(where: { $0.id == clipId }) else {
            print("Failed to find clip with ID: \(clipId)")
            return false
        }
        
        // Get the clip we're moving
        var clipToMove = track.midiClips[clipIndex]
        let clipDuration = clipToMove.duration
        let newEndBeat = newStartBeat + clipDuration
        
        print("Moving clip \(clipToMove.name) from \(clipToMove.startBeat) to \(newStartBeat)")
        
        // Check for overlaps with other clips
        let overlappingClips = track.midiClips.filter { clip in
            clip.id != clipId && // Not the clip we're moving
            (newStartBeat < clip.endBeat && newEndBeat > clip.startBeat) // Overlaps
        }
        
        // Remove any overlapping clips
        for overlappingClip in overlappingClips {
            track.removeMidiClip(id: overlappingClip.id)
            print("Removed overlapping clip: \(overlappingClip.name)")
        }
        
        // Update the clip's position
        clipToMove.startBeat = newStartBeat
        
        // Remove the old clip and add the updated one
        track.removeMidiClip(id: clipId)
        _ = track.addMidiClip(clipToMove)
        
        // Update the track in the project view model
        projectViewModel.updateTrack(at: trackIndex, with: track)
        
        // Update the selection to match the new clip position
        if let timelineState = timelineState,
           timelineState.selectionActive,
           timelineState.selectionTrackId == trackId {
            timelineState.startSelection(at: newStartBeat, trackId: trackId)
            timelineState.updateSelection(to: newEndBeat)
        }
        
        // Ensure the playhead is at the start of the moved clip
        projectViewModel.seekToBeat(newStartBeat)
        
        print("Successfully moved clip to \(newStartBeat)")
        return true
    }
    
    /// Check if a MIDI clip is currently selected on a specific track
    func isMidiClipSelected(trackId: UUID) -> Bool {
        guard let timelineState = findTimelineState(),
              timelineState.selectionActive,
              timelineState.selectionTrackId == trackId,
              let track = projectViewModel?.tracks.first(where: { $0.id == trackId }),
              track.type == .midi else {
            return false
        }
        
        // Get the selection range
        let (selStart, selEnd) = timelineState.normalizedSelectionRange
        
        // Check if the selection matches any clip exactly
        return track.midiClips.contains { clip in
            abs(clip.startBeat - selStart) < 0.001 && abs(clip.endBeat - selEnd) < 0.001
        }
    }
    
    /// Check if a beat position is on a MIDI clip for a specific track
    func isPositionOnMidiClip(trackId: UUID, beatPosition: Double) -> Bool {
        guard let projectViewModel = projectViewModel,
              let track = projectViewModel.tracks.first(where: { $0.id == trackId }),
              track.type == .midi else {
            return false
        }
        
        // Check if the position is within any clip
        let isOnClip = track.midiClips.contains { clip in
            let isWithinClip = beatPosition >= clip.startBeat && beatPosition <= clip.endBeat
            if isWithinClip {
                print("Position \(beatPosition) is on clip: \(clip.name) (clip range: \(clip.startBeat)-\(clip.endBeat))")
                
                // Try to select the clip directly
                if let timelineState = findTimelineState() {
                    projectViewModel.selectTrack(id: trackId)
                    timelineState.startSelection(at: clip.startBeat, trackId: trackId)
                    timelineState.updateSelection(to: clip.endBeat)
                    projectViewModel.seekToBeat(clip.startBeat)
                    print("Directly selected clip: \(clip.name) from \(clip.startBeat) to \(clip.endBeat)")
                }
            }
            return isWithinClip
        }
        
        return isOnClip
    }
    
    /// Set the timeline state reference
    func setTimelineState(_ timelineState: TimelineState) {
        self.timelineState = timelineState
    }
    
    // MARK: - Private Helpers
    
    /// Helper method to find the TimelineState if it exists
    private func findTimelineState() -> TimelineState? {
        // Return the explicitly set timelineState if available
        if let timelineState = timelineState {
            return timelineState
        }
        
        // Otherwise, try to get it from the project view model
        return projectViewModel?.timelineState
    }
} 