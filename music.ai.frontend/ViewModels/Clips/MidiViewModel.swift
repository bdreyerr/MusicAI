import SwiftUI
import Combine

/// MidiViewModel handles all MIDI-related operations and state management
class MidiViewModel: ObservableObject {
    // Reference to the project view model for accessing tracks and other project data
    private weak var projectViewModel: ProjectViewModel?
    
    // Reference to the timeline state
    private weak var timelineState: TimelineStateViewModel?
    
    // Initialize with project view model and timeline state
    init(projectViewModel: ProjectViewModel, timelineState: TimelineStateViewModel? = nil) {
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
              let trackId = projectViewModel.selectedTrackId,
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
        let newClip = MidiClip.createEmpty(
            name: clipName, 
            startBeat: startBeat, 
            duration: duration,
            color: track.effectiveColor  // Use the track's effective color
        )
        
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
        // print("📝 MIDI VM: moveMidiClip CALLED with trackId: \(trackId), clipId: \(clipId), newStartBeat: \(newStartBeat)")
        
        guard let projectViewModel = projectViewModel,
              let trackIndex = projectViewModel.tracks.firstIndex(where: { $0.id == trackId }) else {
            // print("❌ MIDI VM: Failed to find track with ID: \(trackId)")
            return false
        }
        
        // print("📝 MIDI VM: Found track at index: \(trackIndex)")
        
        var track = projectViewModel.tracks[trackIndex]
        
        // Ensure this is a MIDI track
        guard track.type == .midi else {
            // print("❌ MIDI VM: Track is not a MIDI track")
            return false
        }
        
        // Find the clip in the track
        guard let clipIndex = track.midiClips.firstIndex(where: { $0.id == clipId }) else {
            // print("❌ MIDI VM: Failed to find clip with ID: \(clipId)")
            return false
        }
        
        // print("📝 MIDI VM: Found clip at index: \(clipIndex)")
        
        // Get the clip we're moving
        var clipToMove = track.midiClips[clipIndex]
        let clipDuration = clipToMove.duration
        let newEndBeat = newStartBeat + clipDuration
        
        // print("📝 MIDI VM: Moving clip \(clipToMove.name) from \(clipToMove.startBeat) to \(newStartBeat)")
        
        // Check for overlaps with other clips
        let overlappingClips = track.midiClips.filter { clip in
            clip.id != clipId && // Not the clip we're moving
            (newStartBeat < clip.endBeat && newEndBeat > clip.startBeat) // Overlaps
        }
        
        // Remove any overlapping clips
        for overlappingClip in overlappingClips {
            track.removeMidiClip(id: overlappingClip.id)
            // print("📝 MIDI VM: Removed overlapping clip: \(overlappingClip.name)")
        }
        
        // Update the clip's position
        clipToMove.startBeat = newStartBeat
        
        // Remove the old clip and add the updated one
        track.removeMidiClip(id: clipId)
        _ = track.addMidiClip(clipToMove)
        
        // print("📝 MIDI VM: Updated clip position in track")
        
        // Update the track in the project view model
        projectViewModel.updateTrack(at: trackIndex, with: track)
        
        // print("📝 MIDI VM: Updated track in project view model")
        
        // Update the selection to match the new clip position
        if let timelineState = findTimelineState(),
           timelineState.selectionActive,
           projectViewModel.selectedTrackId == trackId {
            timelineState.startSelection(at: newStartBeat, trackId: trackId)
            timelineState.updateSelection(to: newEndBeat)
            // print("📝 MIDI VM: Updated selection to match new clip position")
        }
        
        // Ensure the playhead is at the start of the moved clip
        projectViewModel.seekToBeat(newStartBeat)
        
        // Force UI update by triggering objectWillChange
        projectViewModel.objectWillChange.send()
        
        // print("✅ MIDI VM: Successfully moved clip to \(newStartBeat)")
        return true
    }
    
    /// Resize a MIDI clip by changing its duration
    func resizeMidiClip(trackId: UUID, clipId: UUID, newDuration: Double) -> Bool {
        guard newDuration > 0, // Ensure positive duration
              let projectViewModel = projectViewModel,
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
        
        // Get the clip we're resizing
        var clipToResize = track.midiClips[clipIndex]
        let startBeat = clipToResize.startBeat
        let newEndBeat = startBeat + newDuration
        
        // Check for overlaps with other clips
        let overlappingClips = track.midiClips.filter { clip in
            clip.id != clipId && // Not the clip we're resizing
            (startBeat < clip.endBeat && newEndBeat > clip.startBeat) // Overlaps
        }
        
        // Remove any overlapping clips
        for overlappingClip in overlappingClips {
            track.removeMidiClip(id: overlappingClip.id)
        }
        
        // Update the clip's duration
        clipToResize.duration = newDuration
        
        // Remove the old clip and add the updated one
        track.removeMidiClip(id: clipId)
        _ = track.addMidiClip(clipToResize)
        
        // Update the track in the project view model
        projectViewModel.updateTrack(at: trackIndex, with: track)
        
        // Update the selection to match the new clip size
        if let timelineState = findTimelineState(),
           timelineState.selectionActive,
           projectViewModel.selectedTrackId == trackId {
            timelineState.startSelection(at: startBeat, trackId: trackId)
            timelineState.updateSelection(to: newEndBeat)
        }
        
        // Force UI update by triggering objectWillChange
        projectViewModel.objectWillChange.send()
        
        return true
    }
    
    /// Check if a MIDI clip is currently selected on a specific track
    func isMidiClipSelected(trackId: UUID) -> Bool {
        guard let timelineState = findTimelineState(),
              timelineState.selectionActive,
              projectViewModel?.selectedTrackId == trackId,
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
            beatPosition >= clip.startBeat && beatPosition <= clip.endBeat
        }
        
        return isOnClip
    }
    
    /// Get MIDI clip at a specific position if one exists
    func getMidiClipAt(trackId: UUID, beatPosition: Double) -> MidiClip? {
        guard let projectViewModel = projectViewModel,
              let track = projectViewModel.tracks.first(where: { $0.id == trackId }),
              track.type == .midi else {
            return nil
        }
        
        // Find clip at position
        return track.midiClips.first { clip in
            beatPosition >= clip.startBeat && beatPosition <= clip.endBeat
        }
    }
    
    /// Set the timeline state reference
    func setTimelineState(_ timelineState: TimelineStateViewModel) {
        self.timelineState = timelineState
    }
    
    // Update MIDI Clip Color
    func updateMidiClipColor(trackId: UUID, clipId: UUID, newColor: Color?) -> Bool {
        guard let projectViewModel = projectViewModel else {
            print("❌ MIDI VM: ProjectViewModel is nil, can't update clip color")
            return false
        }
        
        // Find the track index
        guard let trackIndex = projectViewModel.tracks.firstIndex(where: { $0.id == trackId }) else {
            print("❌ MIDI VM: Can't find track with ID \(trackId)")
            return false
        }
        
        // Find the clip index within the track
        guard let clipIndex = projectViewModel.tracks[trackIndex].midiClips.firstIndex(where: { $0.id == clipId }) else {
            print("❌ MIDI VM: Can't find clip with ID \(clipId) in track")
            return false
        }
        
        // Update the clip color
        projectViewModel.tracks[trackIndex].midiClips[clipIndex].color = newColor
        
        // Notify observers
        projectViewModel.objectWillChange.send()
        
        return true
    }
    
    // MARK: - Private Helpers
    
    /// Helper method to find the TimelineState if it exists
    private func findTimelineState() -> TimelineStateViewModel? {
        // Return the explicitly set timelineState if available
        if let timelineState = timelineState {
            return timelineState
        }
        
        // Otherwise, try to get it from the project view model
        return projectViewModel?.timelineState
    }
} 
