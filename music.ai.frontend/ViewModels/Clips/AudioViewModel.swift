import SwiftUI
import Combine
import AVFoundation

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
    
    // MARK: - Audio Item Management
    
    /// Create an AudioItem from a file URL if it doesn't already exist
    /// - Parameters:
    ///   - fileURL: The URL of the audio file
    /// - Returns: The AudioItem (either existing or newly created)
    private func getOrCreateAudioItem(fileURL: URL) async throws -> AudioItem {
        // Check if we already have an AudioItem for this URL
        if let existingItem = projectViewModel?.audioItems.first(where: { $0.audioFileURL == fileURL }) {
            return existingItem
        }
        
        // Create a new AudioItem
        let asset = AVAsset(url: fileURL)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard let audioTrack = tracks.first else {
            throw AudioItemError.invalidAudioFormat
        }
        
        // Load the format description
        let formatDescription = try await audioTrack.load(.formatDescriptions).first as! CMAudioFormatDescription
        guard let streamDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) else {
            throw AudioItemError.invalidAudioFormat
        }
        
        let duration = try await asset.load(.duration).seconds
        let sampleRate = Double(streamDescription.pointee.mSampleRate)
        let channels = Int(streamDescription.pointee.mChannelsPerFrame)
        let bitDepth = Int(streamDescription.pointee.mBitsPerChannel)
        let fileExtension = fileURL.pathExtension.lowercased()
        
        // Calculate the total number of samples
        let lengthInSamples = Int64(duration * sampleRate)
        
        // Generate waveform for the audio file
        // TODO: Generate a real audio waveform from the url, for now it's random
//        let waveform = AudioWaveformGenerator.generateWaveformFromAudioUrl(
//            url: fileURL,
//            color: nil
//        )
        
        let monoWaveform: Waveform?
        let leftWaveform: Waveform?
        let rightWaveform: Waveform?
        
        if channels >= 2 {
            // For stereo files, generate separate waveforms for each channel
            let stereoWaveforms = AudioWaveformGenerator.generateRandomStereoWaveforms()
            monoWaveform = stereoWaveforms.mono
            leftWaveform = stereoWaveforms.left
            rightWaveform = stereoWaveforms.right
        } else {
            // For mono files, just use the mono waveform
            monoWaveform = AudioWaveformGenerator.generateRandomWaveform()
            leftWaveform = nil
            rightWaveform = nil
        }
        
        let newItem = AudioItem(
            name: fileURL.lastPathComponent,
            audioFileURL: fileURL,
            durationInSeconds: duration,
            sampleRate: sampleRate,
            numberOfChannels: channels,
            bitDepth: bitDepth,
            fileFormat: fileExtension,
            monoWaveform: monoWaveform,
            leftWaveform: leftWaveform,
            rightWaveform: rightWaveform,
            lengthInSamples: lengthInSamples
        )
        
        // Add the new item to the project
        DispatchQueue.main.async {
            self.projectViewModel?.audioItems.append(newItem)
        }
        
        
        return newItem
    }
    
    // MARK: - Audio Clip Management
    
    /// Create an audio clip from a dropped file
    /// - Parameters:
    ///   - trackId: The ID of the track to add the clip to
    ///   - filePath: The path to the audio file
    ///   - fileName: The name of the audio file (without extension)
    ///   - startBeat: The starting beat position for the clip
    /// - Returns: True if the clip was created successfully
    func createAudioClipFromFile(trackId: UUID, filePath: String, fileName: String, startBeat: Double) async -> Bool {
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
        
        do {
            // Get or create the AudioItem
            let audioItem = try await getOrCreateAudioItem(fileURL: fileURL)
            
            // Calculate the duration in beats based on the project tempo
            let durationInBeats = AudioFileDurationCalculator.calculateDurationInBeats(
                url: fileURL,
                tempo: projectViewModel.tempo
            )
            
            // Check if we can add a clip at this position (no overlaps)
            guard track.canAddAudioClip(startBeat: startBeat, duration: durationInBeats) else {
                print("Cannot add audio clip at position \(startBeat) - overlaps with existing clips")
                return false
            }
            
            // Create a new audio clip using sample-based properties
            let newClip = AudioClip(
                audioItem: audioItem,
                name: fileName,
                startPositionInBeats: startBeat,
                durationInBeats: durationInBeats,
                audioFileURL: fileURL,
                color: track.effectiveColor,
                originalDuration: durationInBeats,
                waveform: audioItem.waveform,
                startOffsetInSamples: 0, // Start at the beginning of the audio file
                lengthInSamples: audioItem.lengthInSamples // Use the entire audio file
            )
            
            // Add the clip to the track
            track.addAudioClip(newClip)
            
            // Update the track in the project view model
            await MainActor.run {
                projectViewModel.updateTrack(at: trackIndex, with: track)
                
                // Select the new clip
                if let timelineState = self.findTimelineState() {
                    timelineState.startSelection(at: startBeat, trackId: trackId)
                    timelineState.updateSelection(to: startBeat + durationInBeats)
                }
                
                // Move playhead to the start of the clip
                projectViewModel.seekToBeat(startBeat)
            }
            
            return true
        } catch {
            print("Failed to create audio item: \(error)")
            return false
        }
    }
    
    func createAudioClipFromSelection() {
        print("do nothing")
    }
    
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
        let clipDuration = clipToMove.durationInBeats
        let newEndBeat = newStartBeat + clipDuration
        
        // print("📝 AUDIO VM: Moving clip \(clipToMove.name) from \(clipToMove.startPositionInBeats) to \(newStartBeat)")
        
        // Check for overlaps with other clips
        let overlappingClips = track.audioClips.filter { clip in
            clip.id != clipId && // Not the clip we're moving
            (newStartBeat < clip.endBeat && newEndBeat > clip.startPositionInBeats) // Overlaps
        }
        
        // Remove any overlapping clips
        for overlappingClip in overlappingClips {
            track.removeAudioClip(id: overlappingClip.id)
            // print("📝 AUDIO VM: Removed overlapping clip: \(overlappingClip.name)")
        }
        
        // Update the clip's position
        clipToMove.startPositionInBeats = newStartBeat
        
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
    
    /// Resize an audio clip by adjusting its sample window
    /// Returns: A tuple containing (success, actualDuration) where actualDuration is the final duration after applying bounds
    func resizeAudioClip(trackId: UUID, clipId: UUID, newDuration: Double, isResizingLeft: Bool) -> (Bool, Double) {
        guard newDuration > 0, // Ensure positive duration
              let projectViewModel = projectViewModel,
              let trackIndex = projectViewModel.tracks.firstIndex(where: { $0.id == trackId }) else {
            return (false, 0)
        }
        
        var track = projectViewModel.tracks[trackIndex]
        
        // Ensure this is an audio track
        guard track.type == .audio else {
            return (false, 0)
        }
        
        // Find the clip in the track
        guard let clipIndex = track.audioClips.firstIndex(where: { $0.id == clipId }) else {
            return (false, 0)
        }
        
        // Get the clip we're resizing
        var clipToResize = track.audioClips[clipIndex]
        let originalEndBeat = clipToResize.startPositionInBeats + clipToResize.durationInBeats
        
        // Calculate the beat duration in samples
        let samplesPerBeat = Int64(clipToResize.lengthInSamples) / Int64(clipToResize.durationInBeats)
        
        // Calculate new sample values based on which side we're resizing
        if isResizingLeft {
            // When resizing from left, adjust startOffsetInSamples and startPositionInBeats
            let beatDifference = clipToResize.durationInBeats - newDuration
            let sampleDifference = Int64(beatDifference * Double(samplesPerBeat))
            let newStartOffsetInSamples = clipToResize.startOffsetInSamples + sampleDifference
            
            // Ensure we don't go negative with startOffsetInSamples
            if newStartOffsetInSamples < 0 {
                // Calculate the maximum allowed duration based on current startOffsetInSamples
                let maxAdditionalDuration = Double(clipToResize.startOffsetInSamples) / Double(samplesPerBeat)
                let maxNewDuration = clipToResize.durationInBeats + maxAdditionalDuration
                
                // Update duration and startOffsetInSamples
                clipToResize.durationInBeats = maxNewDuration
                clipToResize.startOffsetInSamples = 0
                clipToResize.startPositionInBeats = originalEndBeat - maxNewDuration
                
                // Update the track in the project view model
                track.removeAudioClip(id: clipId)
                _ = track.addAudioClip(clipToResize)
                projectViewModel.updateTrack(at: trackIndex, with: track)
                
                return (true, maxNewDuration)
            }
            
            clipToResize.startOffsetInSamples = newStartOffsetInSamples
            clipToResize.durationInBeats = newDuration
            clipToResize.startPositionInBeats = originalEndBeat - newDuration
        } else {
            // When resizing from right, adjust lengthInSamples
            let beatDifference = newDuration - clipToResize.durationInBeats
            let sampleDifference = Int64(beatDifference * Double(samplesPerBeat))
            let newLengthInSamples = clipToResize.lengthInSamples + sampleDifference
            
            // Ensure we don't exceed the audio file's total samples
            if clipToResize.startOffsetInSamples + newLengthInSamples > clipToResize.audioItem.lengthInSamples {
                // Calculate the maximum allowed samples based on remaining audio
                let remainingAudioInSamples = clipToResize.audioItem.lengthInSamples - clipToResize.startOffsetInSamples
                let maxNewDuration = Double(remainingAudioInSamples) / Double(samplesPerBeat)
                
                // Update duration and lengthInSamples
                clipToResize.durationInBeats = maxNewDuration
                clipToResize.lengthInSamples = remainingAudioInSamples
                
                // Update the track in the project view model
                track.removeAudioClip(id: clipId)
                _ = track.addAudioClip(clipToResize)
                projectViewModel.updateTrack(at: trackIndex, with: track)
                
                return (true, maxNewDuration)
            }
            
            clipToResize.lengthInSamples = newLengthInSamples
            clipToResize.durationInBeats = newDuration
        }
        
        // Check for overlaps with other clips
        let overlappingClips = track.audioClips.filter { clip in
            clip.id != clipId && // Not the clip we're resizing
            (clipToResize.startPositionInBeats < clip.endBeat && 
             (clipToResize.startPositionInBeats + clipToResize.durationInBeats) > clip.startPositionInBeats) // Overlaps
        }
        
        // Remove any overlapping clips
        for overlappingClip in overlappingClips {
            track.removeAudioClip(id: overlappingClip.id)
        }
        
        // Remove the old clip and add the updated one
        track.removeAudioClip(id: clipId)
        _ = track.addAudioClip(clipToResize)
        
        // Update the track in the project view model
        projectViewModel.updateTrack(at: trackIndex, with: track)
        
        return (true, newDuration)
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
            abs(clip.startPositionInBeats - selStart) < 0.001 && abs(clip.endBeat - selEnd) < 0.001
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
            beatPosition >= clip.startPositionInBeats && beatPosition <= clip.endBeat
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
            beatPosition >= clip.startPositionInBeats && beatPosition <= clip.endBeat
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
