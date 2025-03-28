import SwiftUI
import Combine

/// AudioViewModel handles all audio-related operations and state management
class AudioViewModel: ObservableObject {
    // Reference to the project view model for accessing tracks and other project data
    private weak var projectViewModel: ProjectViewModel?
    
    // Reference to the timeline state
    private weak var timelineState: TimelineStateViewModel?
    
    // Initialize with project view model and timeline state
    init(projectViewModel: ProjectViewModel, timelineState: TimelineStateViewModel? = nil) {
        self.projectViewModel = projectViewModel
        self.timelineState = timelineState
    }
    
    // MARK: - Audio Clip Management
    
    /// Create an audio clip from a dropped file
    /// - Parameters:
    ///   - trackId: The ID of the track to add the clip to
    ///   - filePath: The path to the audio file
    ///   - fileName: The name of the audio file (without extension)
    ///   - startBeat: The starting beat position for the clip
    /// - Returns: True if the clip was created successfully
    func createAudioClipFromFile(trackId: UUID, filePath: String, fileName: String, startBeat: Double) -> Bool {
        // Ensure we have a reference to the project view model
        guard let projectViewModel = projectViewModel,
              let trackIndex = projectViewModel.tracks.firstIndex(where: { $0.id == trackId }) else {
            print("Failed to find track with ID: \(trackId)")
            return false
        }
        
        var track = projectViewModel.tracks[trackIndex]
        
        // Ensure this is an audio track
        guard track.type == .audio else {
            print("Track is not an audio track")
            return false
        }
        
        // Create a URL from the file path
        let fileURL = URL(fileURLWithPath: filePath)
        
        // Calculate the duration of the audio file in beats based on the project tempo
        let durationInBeats = AudioFileDurationCalculator.calculateDurationInBeats(
            url: fileURL,
            tempo: projectViewModel.tempo
        )
        
        // Check if we can add a clip at this position (no overlaps)
        guard track.canAddAudioClip(startBeat: startBeat, duration: durationInBeats) else {
            print("Cannot add audio clip at position \(startBeat) - overlaps with existing clips")
            return false
        }
        
        // Generate waveform for the audio file
        let waveform = AudioWaveformGenerator.generateWaveformFromAudioUrl(
            url: fileURL,
            color: track.effectiveColor
        ) ?? AudioWaveformGenerator.generateRandomWaveform(
            color: track.effectiveColor
        )
        
        // Create a new audio clip
        let newClip = AudioClip(
            name: fileName,
            startBeat: startBeat,
            duration: durationInBeats,
            audioFileURL: fileURL,
            color: track.effectiveColor,
            originalDuration: durationInBeats, // Set the original duration to match the actual audio file length
            waveform: waveform
        )
        
        // Add the clip to the track
        track.addAudioClip(newClip)
        
        // Update the track in the project view model
        projectViewModel.updateTrack(at: trackIndex, with: track)
        
        // Select the new clip
        if let timelineState = findTimelineState() {
            timelineState.startSelection(at: startBeat, trackId: trackId)
            timelineState.updateSelection(to: startBeat + durationInBeats)
        }
        
        // Move playhead to the start of the clip
        projectViewModel.seekToBeat(startBeat)
        
        return true
    }
    
    func createAudioClipFromSelection() {
        print("do nothing")
    }
    /// Create an audio clip from the current selection
//    func createAudioClipFromSelection() -> Bool {
//        // Ensure there is an active selection and we have references to required objects
//        guard let projectViewModel = projectViewModel,
//              let timelineState = findTimelineState(),
//              timelineState.selectionActive,
//              let trackId = projectViewModel.selectedTrackId,
//              let trackIndex = projectViewModel.tracks.firstIndex(where: { $0.id == trackId }) else {
//            return false
//        }
//        
//        // Get the selected track
//        var track = projectViewModel.tracks[trackIndex]
//        
//        // Ensure this is an audio track
//        guard track.type == .audio else {
//            return false
//        }
//        
//        // Get the selection range
//        let (startBeat, endBeat) = timelineState.normalizedSelectionRange
//        let duration = endBeat - startBeat
//        
//        // Ensure the duration is valid
//        guard duration > 0 else {
//            return false
//        }
//        
//        // Check if we can add a clip at this position (no overlaps)
//        guard track.canAddAudioClip(startBeat: startBeat, duration: duration) else {
//            return false
//        }
//        
//        // Create a new audio clip
//        let clipName = "Audio \(track.audioClips.count + 1)"
//        let newClip = AudioClip.createEmpty(
//            name: clipName, 
//            startBeat: startBeat, 
//            duration: duration,
//            color: track.effectiveColor
//        )
//        
//        // Add the clip to the track
//        track.addAudioClip(newClip)
//        
//        // Update the track in the project view model
//        projectViewModel.updateTrack(at: trackIndex, with: track)
//        
//        // Clear the selection
//        timelineState.clearSelection()
//        
//        return true
//    }
    
    /// Remove an audio clip from a track
    func removeAudioClip(trackId: UUID, clipId: UUID) -> Bool {
        guard let projectViewModel = projectViewModel,
              let trackIndex = projectViewModel.tracks.firstIndex(where: { $0.id == trackId }) else {
            return false
        }
        
        var track = projectViewModel.tracks[trackIndex]
        
        // Ensure this is an audio track
        guard track.type == .audio else {
            return false
        }
        
        // Remove the clip
        track.removeAudioClip(id: clipId)
        
        // Update the track in the project view model
        projectViewModel.updateTrack(at: trackIndex, with: track)
        
        return true
    }
    
    /// Rename an audio clip
    func renameAudioClip(trackId: UUID, clipId: UUID, newName: String) -> Bool {
        guard let projectViewModel = projectViewModel,
              !newName.isEmpty,
              let trackIndex = projectViewModel.tracks.firstIndex(where: { $0.id == trackId }) else {
            return false
        }
        
        var track = projectViewModel.tracks[trackIndex]
        
        // Ensure this is an audio track
        guard track.type == .audio else {
            return false
        }
        
        // Find the clip in the track
        guard let clipIndex = track.audioClips.firstIndex(where: { $0.id == clipId }) else {
            return false
        }
        
        // Update the clip name
        var updatedClip = track.audioClips[clipIndex]
        updatedClip.name = newName
        track.audioClips[clipIndex] = updatedClip
        
        // Update the track in the project view model
        projectViewModel.updateTrack(at: trackIndex, with: track)
        
        return true
    }
    
    /// Get all audio clips for a specific track
    func audioClipsForTrack(trackId: UUID) -> [AudioClip] {
        guard let projectViewModel = projectViewModel,
              let track = projectViewModel.tracks.first(where: { $0.id == trackId }),
              track.type == .audio else {
            return []
        }
        
        return track.audioClips
    }
    
    /// Move an audio clip to a new position
    func moveAudioClip(trackId: UUID, clipId: UUID, newStartBeat: Double) -> Bool {
        // print("📝 AUDIO VM: moveAudioClip CALLED with trackId: \(trackId), clipId: \(clipId), newStartBeat: \(newStartBeat)")
        
        guard let projectViewModel = projectViewModel,
              let trackIndex = projectViewModel.tracks.firstIndex(where: { $0.id == trackId }) else {
            // print("❌ AUDIO VM: Failed to find track with ID: \(trackId)")
            return false
        }
        
        // print("📝 AUDIO VM: Found track at index: \(trackIndex)")
        
        var track = projectViewModel.tracks[trackIndex]
        
        // Ensure this is an audio track
        guard track.type == .audio else {
            // print("❌ AUDIO VM: Track is not an audio track")
            return false
        }
        
        // Find the clip in the track
        guard let clipIndex = track.audioClips.firstIndex(where: { $0.id == clipId }) else {
            // print("❌ AUDIO VM: Failed to find clip with ID: \(clipId)")
            return false
        }
        
        // print("📝 AUDIO VM: Found clip at index: \(clipIndex)")
        
        // Get the clip we're moving
        var clipToMove = track.audioClips[clipIndex]
        let clipDuration = clipToMove.duration
        let newEndBeat = newStartBeat + clipDuration
        
        // print("📝 AUDIO VM: Moving clip \(clipToMove.name) from \(clipToMove.startBeat) to \(newStartBeat)")
        
        // Check for overlaps with other clips
        let overlappingClips = track.audioClips.filter { clip in
            clip.id != clipId && // Not the clip we're moving
            (newStartBeat < clip.endBeat && newEndBeat > clip.startBeat) // Overlaps
        }
        
        // Remove any overlapping clips
        for overlappingClip in overlappingClips {
            track.removeAudioClip(id: overlappingClip.id)
            // print("📝 AUDIO VM: Removed overlapping clip: \(overlappingClip.name)")
        }
        
        // Update the clip's position
        clipToMove.startBeat = newStartBeat
        
        // Remove the old clip and add the updated one
        track.removeAudioClip(id: clipId)
        _ = track.addAudioClip(clipToMove)
        
        // print("📝 AUDIO VM: Updated clip position in track")
        
        // Update the track in the project view model
        projectViewModel.updateTrack(at: trackIndex, with: track)
        
        // print("📝 AUDIO VM: Updated track in project view model")
        
        // Update the selection to match the new clip position
        if let timelineState = findTimelineState(),
           timelineState.selectionActive,
           projectViewModel.selectedTrackId == trackId {
            timelineState.startSelection(at: newStartBeat, trackId: trackId)
            timelineState.updateSelection(to: newEndBeat)
            // print("📝 AUDIO VM: Updated selection to match new clip position")
        }
        
        // Ensure the playhead is at the start of the moved clip
        projectViewModel.seekToBeat(newStartBeat)
        
        // Force UI update by triggering objectWillChange
        projectViewModel.objectWillChange.send()
        
        // print("✅ AUDIO VM: Successfully moved clip to \(newStartBeat)")
        return true
    }
    
    /// Resize an audio clip by changing its duration
    func resizeAudioClip(trackId: UUID, clipId: UUID, newDuration: Double) -> Bool {
        guard newDuration > 0, // Ensure positive duration
              let projectViewModel = projectViewModel,
              let trackIndex = projectViewModel.tracks.firstIndex(where: { $0.id == trackId }) else {
            return false
        }
        
        var track = projectViewModel.tracks[trackIndex]
        
        // Ensure this is an audio track
        guard track.type == .audio else {
            return false
        }
        
        // Find the clip in the track
        guard let clipIndex = track.audioClips.firstIndex(where: { $0.id == clipId }) else {
            return false
        }
        
        // Get the clip we're resizing
        var clipToResize = track.audioClips[clipIndex]
        let startBeat = clipToResize.startBeat
        
        // Check if we need to limit the new duration based on the original audio file length
        var limitedNewDuration = newDuration
        if let originalDuration = clipToResize.originalDuration {
            // Ensure the new duration doesn't exceed the original audio file duration
            limitedNewDuration = min(newDuration, originalDuration)
        }
        
        let newEndBeat = startBeat + limitedNewDuration
        
        // Check for overlaps with other clips
        let overlappingClips = track.audioClips.filter { clip in
            clip.id != clipId && // Not the clip we're resizing
            (startBeat < clip.endBeat && newEndBeat > clip.startBeat) // Overlaps
        }
        
        // Remove any overlapping clips
        for overlappingClip in overlappingClips {
            track.removeAudioClip(id: overlappingClip.id)
        }
        
        // Update the clip's duration
        clipToResize.duration = limitedNewDuration
        
        // Remove the old clip and add the updated one
        track.removeAudioClip(id: clipId)
        _ = track.addAudioClip(clipToResize)
        
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
    
    /// Check if an audio clip is currently selected on a specific track
    func isAudioClipSelected(trackId: UUID) -> Bool {
        guard let timelineState = findTimelineState(),
              timelineState.selectionActive,
              projectViewModel?.selectedTrackId == trackId,
              let track = projectViewModel?.tracks.first(where: { $0.id == trackId }),
              track.type == .audio else {
            return false
        }
        
        // Get the selection range
        let (selStart, selEnd) = timelineState.normalizedSelectionRange
        
        // Check if the selection matches any clip exactly
        return track.audioClips.contains { clip in
            abs(clip.startBeat - selStart) < 0.001 && abs(clip.endBeat - selEnd) < 0.001
        }
    }
    
    /// Check if a beat position is on an audio clip for a specific track
    func isPositionOnAudioClip(trackId: UUID, beatPosition: Double) -> Bool {
        guard let projectViewModel = projectViewModel,
              let track = projectViewModel.tracks.first(where: { $0.id == trackId }),
              track.type == .audio else {
            return false
        }
        
        // Check if the position is within any clip
        let isOnClip = track.audioClips.contains { clip in
            beatPosition >= clip.startBeat && beatPosition <= clip.endBeat
        }
        
        return isOnClip
    }
    
    /// Get audio clip at a specific position if one exists
    func getAudioClipAt(trackId: UUID, beatPosition: Double) -> AudioClip? {
        guard let projectViewModel = projectViewModel,
              let track = projectViewModel.tracks.first(where: { $0.id == trackId }),
              track.type == .audio else {
            return nil
        }
        
        // Find clip at position
        return track.audioClips.first { clip in
            beatPosition >= clip.startBeat && beatPosition <= clip.endBeat
        }
    }
    
    /// Set the timeline state reference
    func setTimelineState(_ timelineState: TimelineStateViewModel) {
        self.timelineState = timelineState
    }
    
    // Update Audio Clip Color
    func updateAudioClipColor(trackId: UUID, clipId: UUID, newColor: Color?) -> Bool {
        guard let projectViewModel = projectViewModel else {
            print("❌ AUDIO VM: ProjectViewModel is nil, can't update clip color")
            return false
        }
        
        // Find the track index
        guard let trackIndex = projectViewModel.tracks.firstIndex(where: { $0.id == trackId }) else {
            print("❌ AUDIO VM: Can't find track with ID \(trackId)")
            return false
        }
        
        // Find the clip index within the track
        guard let clipIndex = projectViewModel.tracks[trackIndex].audioClips.firstIndex(where: { $0.id == clipId }) else {
            print("❌ AUDIO VM: Can't find clip with ID \(clipId) in track")
            return false
        }
        
        // Update the clip color
        projectViewModel.tracks[trackIndex].audioClips[clipIndex].color = newColor
        
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
