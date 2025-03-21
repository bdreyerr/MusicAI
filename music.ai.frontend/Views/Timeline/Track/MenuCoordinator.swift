import SwiftUI
import AppKit

/// Coordinator class to handle menu actions for the timeline
class MenuCoordinator: NSObject, ObservableObject {
    weak var projectViewModel: ProjectViewModel?
    var defaultTrackHeight: CGFloat = 100 // Default track height
    
    // Clipboard storage for copy/paste operations
    // Changed to support multiple clips with copy counts
    @Published private var clipboardAudioClips: [(AudioClip, Double, Double)]? // [(Clip, startOffset, endOffset)]
    @Published private var clipboardMidiClips: [(MidiClip, Double, Double)]? // [(Clip, startOffset, endOffset)]
    
    // Dictionary to track copy counts for clip names
    private var copyCounts: [String: Int] = [:]
    
    // Computed property to access the MIDI view model
    private var midiViewModel: MidiViewModel? {
        return projectViewModel?.midiViewModel
    }
    
    // Computed property to access the Audio view model
    private var audioViewModel: AudioViewModel? {
        return projectViewModel?.audioViewModel
    }
    
    @objc func addAudioTrack() {
        projectViewModel?.addTrack(name: "Audio \(projectViewModel?.tracks.count ?? 0 + 1)", type: .audio, height: defaultTrackHeight)
    }
    
    @objc func addMidiTrack() {
        projectViewModel?.addTrack(name: "MIDI \(projectViewModel?.tracks.count ?? 0 + 1)", type: .midi, height: defaultTrackHeight)
    }
    
    @objc func createMidiClip() {
        // Create a MIDI clip from the current selection using the MIDI view model
        _ = midiViewModel?.createMidiClipFromSelection()
    }
    
    @objc func createAudioClip() {
        // Create an audio clip from the current selection using the Audio view model
        _ = audioViewModel?.createAudioClipFromSelection()
    }
    
    @objc func renameSelectedClip() {
        guard let projectViewModel = projectViewModel,
              let timelineState = projectViewModel.timelineState,
              timelineState.selectionActive,
              let trackId = projectViewModel.selectedTrackId,
              let track = projectViewModel.tracks.first(where: { $0.id == trackId }) else {
            return
        }
        
        // Get the selection range
        let (selStart, selEnd) = timelineState.normalizedSelectionRange
        
        if track.type == .midi {
            // Find the selected MIDI clip
            guard let selectedClip = track.midiClips.first(where: { 
                abs($0.startBeat - selStart) < 0.001 && abs($0.endBeat - selEnd) < 0.001 
            }) else {
                return
            }
            
            // Show rename dialog
            let alert = NSAlert()
            alert.messageText = "Rename MIDI Clip"
            alert.informativeText = "Enter a new name for this clip:"
            
            let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
            textField.stringValue = selectedClip.name
            alert.accessoryView = textField
            
            alert.addButton(withTitle: "Rename")
            alert.addButton(withTitle: "Cancel")
            
            if alert.runModal() == .alertFirstButtonReturn {
                let newName = textField.stringValue
                if !newName.isEmpty {
                    _ = midiViewModel?.renameMidiClip(trackId: trackId, clipId: selectedClip.id, newName: newName)
                }
            }
        } else if track.type == .audio {
            // Find the selected audio clip
            guard let selectedClip = track.audioClips.first(where: { 
                abs($0.startBeat - selStart) < 0.001 && abs($0.endBeat - selEnd) < 0.001 
            }) else {
                return
            }
            
            // Show rename dialog
            let alert = NSAlert()
            alert.messageText = "Rename Audio Clip"
            alert.informativeText = "Enter a new name for this clip:"
            
            let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
            textField.stringValue = selectedClip.name
            alert.accessoryView = textField
            
            alert.addButton(withTitle: "Rename")
            alert.addButton(withTitle: "Cancel")
            
            if alert.runModal() == .alertFirstButtonReturn {
                let newName = textField.stringValue
                if !newName.isEmpty {
                    _ = audioViewModel?.renameAudioClip(trackId: trackId, clipId: selectedClip.id, newName: newName)
                }
            }
        }
    }
    
    // Note this function may delete multiple clips
    @objc func deleteSelectedClip() {
        guard let projectViewModel = projectViewModel,
              let timelineState = projectViewModel.timelineState,
              timelineState.selectionActive,
              let trackId = projectViewModel.selectedTrackId,
              let track = projectViewModel.tracks.first(where: { $0.id == trackId }) else {
            return
        }
        
        // Get the selection range
        let (selStart, selEnd) = timelineState.normalizedSelectionRange
        
        if track.type == .midi {
            // Get all MIDI clips that overlap with the selection
            let overlappingClips = track.midiClips.filter { clip in
                // Check if the selection overlaps with this clip
                selStart < clip.endBeat && selEnd > clip.startBeat
            }
            
            if overlappingClips.isEmpty {
                // No clips to delete or trim
                return
            }
            
            // Separate fully contained clips from partially overlapping ones
            let fullyContainedClips = overlappingClips.filter { clip in
                selStart <= clip.startBeat && selEnd >= clip.endBeat
            }
            
            let partiallyOverlappingClips = overlappingClips.filter { clip in
                !(selStart <= clip.startBeat && selEnd >= clip.endBeat)
            }
            
            // If we're deleting any full clips, show a confirmation dialog
            if !fullyContainedClips.isEmpty {
                let clipWord = fullyContainedClips.count == 1 ? "clip" : "clips"
                let alert = NSAlert()
                alert.messageText = "Delete \(fullyContainedClips.count) MIDI \(clipWord)"
                alert.informativeText = "Are you sure you want to delete \(fullyContainedClips.count) MIDI \(clipWord)? This action cannot be undone."
                alert.alertStyle = .warning
                
                alert.addButton(withTitle: "Delete")
                alert.addButton(withTitle: "Cancel")
                
                let response = alert.runModal()
                if response != .alertFirstButtonReturn {
                    return // User canceled the deletion
                }
            }
            
            // Delete all fully contained clips
            for clip in fullyContainedClips {
                _ = midiViewModel?.removeMidiClip(trackId: trackId, clipId: clip.id)
            }
            
            // Process partial clips (trim or split)
            for clip in partiallyOverlappingClips {
                // Check if selection is at the beginning of the clip
                if selStart <= clip.startBeat && selEnd < clip.endBeat {
                    // Selection is at the beginning of the clip - keep the end part
                    let newStartBeat = selEnd
                    let newDuration = clip.endBeat - selEnd
                    
                    // Move the clip to the new start and update duration
                    _ = midiViewModel?.moveMidiClip(trackId: trackId, clipId: clip.id, newStartBeat: newStartBeat)
                    _ = midiViewModel?.resizeMidiClip(trackId: trackId, clipId: clip.id, newDuration: newDuration)
                }
                // Check if selection is at the end of the clip
                else if selStart > clip.startBeat && selEnd >= clip.endBeat {
                    // Selection is at the end of the clip - keep the beginning part
                    let newDuration = selStart - clip.startBeat
                    
                    // Update clip duration
                    _ = midiViewModel?.resizeMidiClip(trackId: trackId, clipId: clip.id, newDuration: newDuration)
                }
                // Check if selection is in the middle of the clip
                else if selStart > clip.startBeat && selEnd < clip.endBeat {
                    // Selection is in the middle of the clip - split into two clips
                    
                    // First, create a new clip for the end portion
                    let endClipDuration = clip.endBeat - selEnd
                    
                    // Adjust the original clip to be just the beginning portion
                    let beginningClipDuration = selStart - clip.startBeat
                    
                    // Now resize the original clip to be the beginning portion
                    _ = midiViewModel?.resizeMidiClip(trackId: trackId, clipId: clip.id, newDuration: beginningClipDuration)
                    
                    // Create a new clip for the end portion if it has meaningful duration
                    if endClipDuration > 0.01 {
                        // We need to create a duplicate of the original clip
                        var endClip = MidiClip(
                            name: clip.name + " (split)",
                            startBeat: selEnd,
                            duration: endClipDuration,
                            color: clip.color,
                            notes: [] // Note: this doesn't copy the notes - would need more complex logic to handle that
                        )
                        
                        // Create a mutable copy of the track
                        var mutableTrack = track
                        
                        // Add the clip to the track
                        _ = mutableTrack.addMidiClip(endClip)
                        
                        // Update the track in the project view model
                        if let trackIndex = projectViewModel.tracks.firstIndex(where: { $0.id == trackId }) {
                            projectViewModel.updateTrack(at: trackIndex, with: mutableTrack)
                        }
                    }
                }
            }
        } else if track.type == .audio {
            // Get all audio clips that overlap with the selection
            let overlappingClips = track.audioClips.filter { clip in
                // Check if the selection overlaps with this clip
                selStart < clip.endBeat && selEnd > clip.startBeat
            }
            
            if overlappingClips.isEmpty {
                // No clips to delete or trim
                return
            }
            
            // Separate fully contained clips from partially overlapping ones
            let fullyContainedClips = overlappingClips.filter { clip in
                selStart <= clip.startBeat && selEnd >= clip.endBeat
            }
            
            let partiallyOverlappingClips = overlappingClips.filter { clip in
                !(selStart <= clip.startBeat && selEnd >= clip.endBeat)
            }
            
            // If we're deleting any full clips, show a confirmation dialog
            if !fullyContainedClips.isEmpty {
                let clipWord = fullyContainedClips.count == 1 ? "clip" : "clips"
                let alert = NSAlert()
                alert.messageText = "Delete \(fullyContainedClips.count) Audio \(clipWord)"
                alert.informativeText = "Are you sure you want to delete \(fullyContainedClips.count) audio \(clipWord)? This action cannot be undone."
                alert.alertStyle = .warning
                
                alert.addButton(withTitle: "Delete")
                alert.addButton(withTitle: "Cancel")
                
                let response = alert.runModal()
                if response != .alertFirstButtonReturn {
                    return // User canceled the deletion
                }
            }
            
            // Delete all fully contained clips
            for clip in fullyContainedClips {
                _ = audioViewModel?.removeAudioClip(trackId: trackId, clipId: clip.id)
            }
            
            // Process partial clips (trim or split)
            for clip in partiallyOverlappingClips {
                // Check if selection is at the beginning of the clip
                if selStart <= clip.startBeat && selEnd < clip.endBeat {
                    // Selection is at the beginning of the clip - keep the end part
                    let newStartBeat = selEnd
                    let newDuration = clip.endBeat - selEnd
                    
                    // Move the clip to the new start and update duration
                    _ = audioViewModel?.moveAudioClip(trackId: trackId, clipId: clip.id, newStartBeat: newStartBeat)
                    _ = audioViewModel?.resizeAudioClip(trackId: trackId, clipId: clip.id, newDuration: newDuration)
                }
                // Check if selection is at the end of the clip
                else if selStart > clip.startBeat && selEnd >= clip.endBeat {
                    // Selection is at the end of the clip - keep the beginning part
                    let newDuration = selStart - clip.startBeat
                    
                    // Update clip duration
                    _ = audioViewModel?.resizeAudioClip(trackId: trackId, clipId: clip.id, newDuration: newDuration)
                }
                // Check if selection is in the middle of the clip
                else if selStart > clip.startBeat && selEnd < clip.endBeat {
                    // Selection is in the middle of the clip - split into two clips
                    
                    // First, create a new clip for the end portion
                    let endClipDuration = clip.endBeat - selEnd
                    
                    // Adjust the original clip to be just the beginning portion
                    let beginningClipDuration = selStart - clip.startBeat
                    
                    // Now resize the original clip to be the beginning portion
                    _ = audioViewModel?.resizeAudioClip(trackId: trackId, clipId: clip.id, newDuration: beginningClipDuration)
                    
                    // Create a new clip for the end portion if it has meaningful duration
                    if endClipDuration > 0.01 {
                        // We need to create a duplicate of the original clip
                        var endClip = AudioClip(
                            name: clip.name + " (split)",
                            startBeat: selEnd,
                            duration: endClipDuration,
                            color: clip.color
                        )
                        
                        // Create a mutable copy of the track
                        var mutableTrack = track
                        
                        // Add the clip to the track
                        _ = mutableTrack.addAudioClip(endClip)
                        
                        // Update the track in the project view model
                        if let trackIndex = projectViewModel.tracks.firstIndex(where: { $0.id == trackId }) {
                            projectViewModel.updateTrack(at: trackIndex, with: mutableTrack)
                        }
                    }
                }
            }
        }
        
        // Clear the selection since we've performed the operation
        timelineState.clearSelection()
    }
    
    @objc func editClipNotes() {
        // This would open the piano roll editor for the selected MIDI clip
        // For now, we'll just print a message
        print("Edit notes functionality will be implemented later")
    }
    
    @objc func editAudioClip() {
        // This would open the audio editor for the selected audio clip
        // For now, we'll just print a message
        print("Edit audio functionality will be implemented later")
    }
    
    @objc func copySelectedClip() {
        guard let projectViewModel = projectViewModel,
              let timelineState = projectViewModel.timelineState,
              timelineState.selectionActive,
              let trackId = projectViewModel.selectedTrackId,
              let track = projectViewModel.tracks.first(where: { $0.id == trackId }) else {
            return
        }
        
        // Get the selection range
        let (selStart, selEnd) = timelineState.normalizedSelectionRange
        
        if track.type == .midi {
            // Clear any existing clipboard data
            clipboardAudioClips = nil
            
            // Get all MIDI clips that overlap with the selection
            let overlappingClips = track.midiClips.filter { clip in
                // Check if the selection overlaps with this clip
                selStart < clip.endBeat && selEnd > clip.startBeat
            }
            
            if overlappingClips.isEmpty {
                // No clips to copy - do nothing and return
                return
            }
            
            // Initialize array to store copied clips
            var clipsToCopy: [(MidiClip, Double, Double)] = []
            
            // Check if we have an exact clip match (fully selected clip)
            let fullyContainedClips = overlappingClips.filter { clip in
                abs(clip.startBeat - selStart) < 0.001 && abs(clip.endBeat - selEnd) < 0.001
            }
            
            if !fullyContainedClips.isEmpty {
                // Full clips selected, add all to clipboard
                for clip in fullyContainedClips {
                    clipsToCopy.append((clip, 0.0, 0.0))
                }
                
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("MIDI Clips: \(fullyContainedClips.count)", forType: .string)
            } else {
                // Handle partial clips
                for clip in overlappingClips {
                    // Calculate offsets (how much of the clip we're copying)
                    let startOffset = max(0, selStart - clip.startBeat)
                    let endOffset = max(0, clip.endBeat - selEnd)
                    
                    clipsToCopy.append((clip, startOffset, endOffset))
                }
                
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("Partial MIDI Clips: \(overlappingClips.count)", forType: .string)
            }
            
            // Store the copied clips
            clipboardMidiClips = clipsToCopy
            
        } else if track.type == .audio {
            // Clear any existing clipboard data
            clipboardMidiClips = nil
            
            // Get all audio clips that overlap with the selection
            let overlappingClips = track.audioClips.filter { clip in
                // Check if the selection overlaps with this clip
                selStart < clip.endBeat && selEnd > clip.startBeat
            }
            
            if overlappingClips.isEmpty {
                // No clips to copy - do nothing and return
                return
            }
            
            // Initialize array to store copied clips
            var clipsToCopy: [(AudioClip, Double, Double)] = []
            
            // Check if we have exact clip matches (fully selected clips)
            let fullyContainedClips = overlappingClips.filter { clip in
                abs(clip.startBeat - selStart) < 0.001 && abs(clip.endBeat - selEnd) < 0.001
            }
            
            if !fullyContainedClips.isEmpty {
                // Full clips selected, add all to clipboard
                for clip in fullyContainedClips {
                    clipsToCopy.append((clip, 0.0, 0.0))
                }
                
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("Audio Clips: \(fullyContainedClips.count)", forType: .string)
            } else {
                // Handle partial clips
                for clip in overlappingClips {
                    // Calculate offsets (how much of the clip we're copying)
                    let startOffset = max(0, selStart - clip.startBeat)
                    let endOffset = max(0, clip.endBeat - selEnd)
                    
                    clipsToCopy.append((clip, startOffset, endOffset))
                }
                
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("Partial Audio Clips: \(overlappingClips.count)", forType: .string)
            }
            
            // Store the copied clips
            clipboardAudioClips = clipsToCopy
        }
    }
    
    @objc func pasteClip() {
        guard let projectViewModel = projectViewModel,
              let timelineState = projectViewModel.timelineState,
              let trackId = projectViewModel.selectedTrackId,
              let trackIndex = projectViewModel.tracks.firstIndex(where: { $0.id == trackId }) else {
            return
        }
        
        var track = projectViewModel.tracks[trackIndex]
        
        // Get the current playhead position as paste location
        let pastePosition = projectViewModel.currentBeat
        
        if track.type == .midi {
            // Check if we have MIDI clip data to paste
            guard let clipsToPaste = clipboardMidiClips, !clipsToPaste.isEmpty else {
                // No MIDI clip in clipboard
                return
            }
            
            // Find the earliest start beat in the original clips to use as reference point
            let originalStartPositions = clipsToPaste.map { $0.0.startBeat }
            let earliestOriginalPosition = originalStartPositions.min() ?? 0.0
            
            // Calculate total span of all clips to be pasted
            var latestEndBeat = pastePosition
            var clipsToAdd: [MidiClip] = []
            
            // Prepare all clips, preserving their relative positions
            for (originalClip, startOffset, endOffset) in clipsToPaste {
                // Calculate the duration of the clip to paste
                let originalDuration = originalClip.duration
                let newDuration = originalDuration - startOffset - endOffset
                
                // Get the clip name with proper numbering
                let baseName = originalClip.name.replacingOccurrences(of: " \\(copy \\d+\\)$", with: "", options: .regularExpression)
                let copyCount = getNextCopyCount(for: baseName)
                let newName = "\(baseName) (copy \(copyCount))"
                
                // Calculate new position preserving the relative spacing from original
                let offsetFromReference = originalClip.startBeat - earliestOriginalPosition
                let newStartBeat = pastePosition + offsetFromReference
                
                // Create a new clip with adjusted timing
                var newClip = MidiClip(
                    name: newName,
                    startBeat: newStartBeat,
                    duration: newDuration,
                    color: originalClip.color
                )
                
                // Copy notes from the original clip
                if startOffset == 0 && endOffset == 0 {
                    // Full clip copy - copy all notes with position adjustments
                    for note in originalClip.notes {
                        let newNote = MidiNote(
                            pitch: note.pitch,
                            startBeat: note.startBeat,
                            duration: note.duration,
                            velocity: note.velocity
                        )
                        newClip.notes.append(newNote)
                    }
                } else {
                    // Partial clip copy - only copy notes that fall within the selected region
                    let originalStartBeat = originalClip.startBeat
                    let selectionStart = originalStartBeat + startOffset
                    let selectionEnd = originalClip.endBeat - endOffset
                    
                    for note in originalClip.notes {
                        let noteStartInTimeline = originalStartBeat + note.startBeat
                        let noteEndInTimeline = noteStartInTimeline + note.duration
                        
                        // Only include notes that are within the selection
                        if noteStartInTimeline < selectionEnd && noteEndInTimeline > selectionStart {
                            // Calculate new position relative to the new clip start
                            let newStartBeat = max(0, noteStartInTimeline - selectionStart)
                            
                            // Calculate new duration, truncating if needed
                            let newEndBeat = min(noteEndInTimeline, selectionEnd) - selectionStart
                            let newDuration = newEndBeat - newStartBeat
                            
                            if newDuration > 0 {
                                let newNote = MidiNote(
                                    pitch: note.pitch,
                                    startBeat: newStartBeat,
                                    duration: newDuration,
                                    velocity: note.velocity
                                )
                                newClip.notes.append(newNote)
                            }
                        }
                    }
                }
                
                clipsToAdd.append(newClip)
                // Update the latest end beat
                latestEndBeat = max(latestEndBeat, newStartBeat + newDuration)
            }
            
            // Check if we can add all clips (no overlaps)
            let canAddClips = track.canAddMidiClips(startingAt: pastePosition, clips: clipsToAdd)
            
            if canAddClips {
                // Add all clips
                for clip in clipsToAdd {
                    track.addMidiClip(clip)
                }
                
                // Update the track in the project
                projectViewModel.updateTrack(at: trackIndex, with: track)
                
                // Select the pasted area
                timelineState.startSelection(at: pastePosition, trackId: trackId)
                timelineState.updateSelection(to: latestEndBeat)
            } else {
                // Show error alert - can't paste here due to overlapping clips
                let alert = NSAlert()
                alert.messageText = "Cannot Paste Clips"
                alert.informativeText = "The clips cannot be pasted at the current position because they would overlap with existing clips."
                alert.alertStyle = .warning
                alert.runModal()
            }
        } else if track.type == .audio {
            // Check if we have audio clip data to paste
            guard let clipsToPaste = clipboardAudioClips, !clipsToPaste.isEmpty else {
                // No audio clip in clipboard
                return
            }
            
            // Find the earliest start beat in the original clips to use as reference point
            let originalStartPositions = clipsToPaste.map { $0.0.startBeat }
            let earliestOriginalPosition = originalStartPositions.min() ?? 0.0
            
            // Calculate total span of all clips to be pasted
            var latestEndBeat = pastePosition
            var clipsToAdd: [AudioClip] = []
            
            // Prepare all clips, preserving their relative positions
            for (originalClip, startOffset, endOffset) in clipsToPaste {
                // Calculate the duration of the clip to paste
                let originalDuration = originalClip.duration
                let newDuration = originalDuration - startOffset - endOffset
                
                // Get the clip name with proper numbering
                let baseName = originalClip.name.replacingOccurrences(of: " \\(copy \\d+\\)$", with: "", options: .regularExpression)
                let copyCount = getNextCopyCount(for: baseName)
                let newName = "\(baseName) (copy \(copyCount))"
                
                // Calculate new position preserving the relative spacing from original
                let offsetFromReference = originalClip.startBeat - earliestOriginalPosition
                let newStartBeat = pastePosition + offsetFromReference
                
                // Create a new clip with adjusted timing
                var newClip = AudioClip(
                    name: newName,
                    startBeat: newStartBeat,
                    duration: newDuration,
                    color: originalClip.color,
                    waveformData: originalClip.waveformData
                )
                
                clipsToAdd.append(newClip)
                // Update the latest end beat
                latestEndBeat = max(latestEndBeat, newStartBeat + newDuration)
            }
            
            // Check if we can add all clips (no overlaps)
            let canAddClips = track.canAddAudioClips(startingAt: pastePosition, clips: clipsToAdd)
            
            if canAddClips {
                // Add all clips
                for clip in clipsToAdd {
                    track.addAudioClip(clip)
                }
                
                // Update the track in the project
                projectViewModel.updateTrack(at: trackIndex, with: track)
                
                // Select the pasted area
                timelineState.startSelection(at: pastePosition, trackId: trackId)
                timelineState.updateSelection(to: latestEndBeat)
            } else {
                // Show error alert - can't paste here due to overlapping clips
                let alert = NSAlert()
                alert.messageText = "Cannot Paste Clips"
                alert.informativeText = "The clips cannot be pasted at the current position because they would overlap with existing clips."
                alert.alertStyle = .warning
                alert.runModal()
            }
        } else {
            // Not an audio or MIDI track, can't paste clips here
            let alert = NSAlert()
            alert.messageText = "Cannot Paste Clips"
            alert.informativeText = "Clips can only be pasted onto the same type of track (audio or MIDI)."
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
    
    // Helper method to get the next copy count for a clip name
    private func getNextCopyCount(for baseName: String) -> Int {
        let count = copyCounts[baseName] ?? 0
        let newCount = count + 1
        copyCounts[baseName] = newCount
        return newCount
    }
} 
