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
        projectViewModel?.addTrack(type: .audio, height: defaultTrackHeight)
    }
    
    @objc func addMidiTrack() {
        projectViewModel?.addTrack(type: .midi, height: defaultTrackHeight)
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
    
    @objc func deleteSelectedClip() {
        guard let projectViewModel = projectViewModel,
              let timelineState = projectViewModel.timelineState,
              let trackId = projectViewModel.selectedTrackId,
              let track = projectViewModel.tracks.first(where: { $0.id == trackId }) else {
            return
        }
        
        // Get any multi-selected clips
        let selectedClipIds = timelineState.selectedClipIds
        
        if track.type == .midi {
            // Check if we have multi-selected clips
            if !selectedClipIds.isEmpty {
                // Get all selected clips from this track
                let selectedClips = track.midiClips.filter { clip in
                    selectedClipIds.contains(clip.id)
                }
                
                if !selectedClips.isEmpty {
                    // Delete all selected clips
                    for clip in selectedClips {
                        _ = midiViewModel?.removeMidiClip(trackId: trackId, clipId: clip.id)
                    }
                    
                    // Clear the selection
                    timelineState.clearSelection()
                    return
                }
            }
            
            // If no multi-selection, check for clips in the selection range
            if timelineState.selectionActive {
                // Get the selection range
                let (selStart, selEnd) = timelineState.normalizedSelectionRange
                
                // Find any clips that overlap with the selection
                let overlappingClips = track.midiClips.filter { clip in
                    selStart < clip.endBeat && selEnd > clip.startBeat
                }
                
                if !overlappingClips.isEmpty {
                    // Process each overlapping clip
                    for clip in overlappingClips {
                        if selStart <= clip.startBeat && selEnd >= clip.endBeat {
                            // Full clip is within selection - delete it
                            _ = midiViewModel?.removeMidiClip(trackId: trackId, clipId: clip.id)
                        } else if selStart > clip.startBeat && selEnd < clip.endBeat {
                            // Selection is completely in the middle of the clip - split into two clips
                            print("DEBUG: Processing selection within MIDI clip - clipId: \(clip.id), clipName: \(clip.name)")
                            print("DEBUG: Selection range: \(selStart) to \(selEnd)")
                            print("DEBUG: Original clip range: \(clip.startBeat) to \(clip.endBeat)")
                            
                            // Store the original clip data before modifications
                            let originalClipId = clip.id
                            let originalStartBeat = clip.startBeat
                            let originalEndBeat = clip.endBeat
                            let originalDuration = clip.duration
                            let originalNotes = clip.notes
                            let originalColor = clip.color
                            
                            // STEP 1: REMOVE THE ORIGINAL CLIP
                            // This is the key change - we need to remove the original clip completely, then add two new clips
                            print("DEBUG: Removing original clip before creating new clips")
                            _ = midiViewModel?.removeMidiClip(trackId: trackId, clipId: originalClipId)
                            
                            // STEP 2: CREATE THE FIRST (LEFT) CLIP
                            // First part - from original start to selStart
                            let firstPartName = clip.name
                            let firstPartStartBeat = originalStartBeat
                            let firstPartDuration = selStart - originalStartBeat
                            print("DEBUG: Creating first part - name: \(firstPartName), startBeat: \(firstPartStartBeat), duration: \(firstPartDuration)")
                            
                            // Filter notes that should be in the first part (before the selection)
                            let firstPartNotes = originalNotes.compactMap { note -> MidiNote? in
                                let noteStartBeat = note.startBeat
                                let noteEndBeat = noteStartBeat + note.duration
                                
                                // Only keep notes that end before the selection
                                if noteEndBeat <= (selStart - originalStartBeat) {
                                    return note
                                }
                                // If note crosses the start boundary
                                else if noteStartBeat < (selStart - originalStartBeat) && noteEndBeat > (selStart - originalStartBeat) {
                                    // Truncate the note at selection start
                                    let newDuration = selStart - originalStartBeat - noteStartBeat
                                    return MidiNote(
                                        pitch: note.pitch,
                                        startBeat: noteStartBeat,
                                        duration: newDuration,
                                        velocity: note.velocity
                                    )
                                }
                                return nil
                            }
                            
                            // Create the first clip
                            let firstPart = MidiClip(
                                name: firstPartName,
                                startBeat: firstPartStartBeat,
                                duration: firstPartDuration,
                                color: originalColor,
                                notes: firstPartNotes
                            )
                            
                            // STEP 3: CREATE THE SECOND (RIGHT) CLIP
                            // Second part - from selEnd to original end
                            let secondPartName = "\(clip.name) (2)"
                            let secondPartStartBeat = selEnd
                            let secondPartDuration = originalEndBeat - selEnd
                            print("DEBUG: Creating second part - name: \(secondPartName), startBeat: \(secondPartStartBeat), duration: \(secondPartDuration)")
                            
                            // Filter notes that belong in the second part (after the selection)
                            let secondPartNotes = originalNotes.compactMap { note -> MidiNote? in
                                let noteStartBeat = originalStartBeat + note.startBeat
                                let noteEndBeat = noteStartBeat + note.duration
                                
                                // If note is entirely after the selection
                                if noteStartBeat >= selEnd {
                                    // Create a new note with adjusted position relative to the new clip start
                                    return MidiNote(
                                        pitch: note.pitch, 
                                        startBeat: noteStartBeat - selEnd, // Adjust position relative to new clip
                                        duration: note.duration,
                                        velocity: note.velocity
                                    )
                                // If note crosses the selection end boundary
                                } else if noteEndBeat > selEnd {
                                    // Only keep the portion after selection, with adjusted start/duration
                                    let newStartBeat = 0.0 // Start at beginning of new clip
                                    let newDuration = noteEndBeat - selEnd
                                    return MidiNote(
                                        pitch: note.pitch,
                                        startBeat: newStartBeat,
                                        duration: newDuration,
                                        velocity: note.velocity
                                    )
                                }
                                return nil
                            }
                            
                            // Create the second clip
                            let secondPart = MidiClip(
                                name: secondPartName,
                                startBeat: secondPartStartBeat,
                                duration: secondPartDuration,
                                color: originalColor,
                                notes: secondPartNotes
                            )
                            
                            // STEP 4: ADD BOTH CLIPS TO THE TRACK
                            // Get a fresh copy of the track (which should now have the original clip removed)
                            if let trackIndex = projectViewModel.tracks.firstIndex(where: { $0.id == trackId }),
                               var updatedTrack = projectViewModel.tracks.first(where: { $0.id == trackId }) {
                                
                                print("DEBUG: Current clip count before adding new clips: \(updatedTrack.midiClips.count)")
                                
                                // Add both new clips
                                updatedTrack.addMidiClip(firstPart)
                                updatedTrack.addMidiClip(secondPart)
                                
                                // Update the track in the project with a single operation
                                print("DEBUG: Adding both new clips to track. Adding \(firstPartName) at \(firstPartStartBeat) and \(secondPartName) at \(secondPartStartBeat)")
                                projectViewModel.updateTrack(at: trackIndex, with: updatedTrack)
                                print("DEBUG: Split operation complete - created two clips with empty space between them")
                            } else {
                                print("ERROR: Could not find track to update after removing original clip")
                            }
                        } else if selStart <= clip.startBeat && selEnd < clip.endBeat {
                            // Selection cuts the beginning - resize and move
                            let newStartBeat = selEnd
                            let newDuration = clip.endBeat - selEnd
                            
                            // Move the clip to the new position
                            _ = midiViewModel?.moveMidiClip(trackId: trackId, clipId: clip.id, newStartBeat: newStartBeat)
                            _ = midiViewModel?.resizeMidiClip(trackId: trackId, clipId: clip.id, newDuration: newDuration)
                        } else if selStart > clip.startBeat && selEnd >= clip.endBeat {
                            // Selection cuts the end - just resize
                            let newDuration = selStart - clip.startBeat
                            _ = midiViewModel?.resizeMidiClip(trackId: trackId, clipId: clip.id, newDuration: newDuration)
                        }
                    }
                    
                    // Clear the selection after processing
                    timelineState.clearSelection()
                }
            }
        } else if track.type == .audio {
            // Check if we have multi-selected clips
            if !selectedClipIds.isEmpty {
                // Get all selected clips from this track
                let selectedClips = track.audioClips.filter { clip in
                    selectedClipIds.contains(clip.id)
                }
                
                if !selectedClips.isEmpty {
                    // Delete all selected clips
                    for clip in selectedClips {
                        _ = audioViewModel?.removeAudioClip(trackId: trackId, clipId: clip.id)
                    }
                    
                    // Clear the selection
                    timelineState.clearSelection()
                    return
                }
            }
            
            // If no multi-selection, check for clips in the selection range
            if timelineState.selectionActive {
                // Get the selection range
                let (selStart, selEnd) = timelineState.normalizedSelectionRange
                
                // Find any clips that overlap with the selection
                let overlappingClips = track.audioClips.filter { clip in
                    selStart < clip.endBeat && selEnd > clip.startBeat
                }
                
                if !overlappingClips.isEmpty {
                    // Process each overlapping clip
                    for clip in overlappingClips {
                        if selStart <= clip.startBeat && selEnd >= clip.endBeat {
                            // Full clip is within selection - delete it
                            _ = audioViewModel?.removeAudioClip(trackId: trackId, clipId: clip.id)
                        } else if selStart > clip.startBeat && selEnd < clip.endBeat {
                            // Selection is in the middle - split into two clips
                            print("DEBUG: Processing selection within Audio clip - clipId: \(clip.id), clipName: \(clip.name)")
                            print("DEBUG: Selection range: \(selStart) to \(selEnd)")
                            print("DEBUG: Original clip range: \(clip.startBeat) to \(clip.endBeat)")
                            
                            // Store the original clip data before modifications
                            let originalClipId = clip.id
                            let originalStartBeat = clip.startBeat
                            let originalEndBeat = clip.endBeat
                            let originalDuration = clip.duration
                            let originalWaveformData = clip.waveformData
                            let originalColor = clip.color
                            
                            // STEP 1: REMOVE THE ORIGINAL CLIP
                            // This is the key change - we need to remove the original clip completely, then add two new clips
                            print("DEBUG: Removing original audio clip before creating new clips")
                            _ = audioViewModel?.removeAudioClip(trackId: trackId, clipId: originalClipId)
                            
                            // STEP 2: CREATE THE FIRST (LEFT) CLIP
                            // First part - from original start to selStart
                            let firstPartName = clip.name
                            let firstPartStartBeat = originalStartBeat
                            let firstPartDuration = selStart - originalStartBeat
                            print("DEBUG: Creating first audio part - name: \(firstPartName), startBeat: \(firstPartStartBeat), duration: \(firstPartDuration)")
                            
                            // Create the first clip
                            let firstPart = AudioClip(
                                name: firstPartName,
                                startBeat: firstPartStartBeat,
                                duration: firstPartDuration,
                                color: originalColor,
                                waveformData: originalWaveformData
                            )
                            
                            // STEP 3: CREATE THE SECOND (RIGHT) CLIP
                            // Second part - from selEnd to original end
                            let secondPartName = "\(clip.name) (2)"
                            let secondPartStartBeat = selEnd
                            let secondPartDuration = originalEndBeat - selEnd
                            print("DEBUG: Creating second audio part - name: \(secondPartName), startBeat: \(secondPartStartBeat), duration: \(secondPartDuration)")
                            
                            // Create the second clip
                            let secondPart = AudioClip(
                                name: secondPartName,
                                startBeat: secondPartStartBeat,
                                duration: secondPartDuration,
                                color: originalColor,
                                waveformData: originalWaveformData
                            )
                            
                            // STEP 4: ADD BOTH CLIPS TO THE TRACK
                            // Get a fresh copy of the track (which should now have the original clip removed)
                            if let trackIndex = projectViewModel.tracks.firstIndex(where: { $0.id == trackId }),
                               var updatedTrack = projectViewModel.tracks.first(where: { $0.id == trackId }) {
                                
                                print("DEBUG: Current audio clip count before adding new clips: \(updatedTrack.audioClips.count)")
                                
                                // Add both new clips
                                updatedTrack.addAudioClip(firstPart)
                                updatedTrack.addAudioClip(secondPart)
                                
                                // Update the track in the project with a single operation
                                print("DEBUG: Adding both new audio clips to track. Adding \(firstPartName) at \(firstPartStartBeat) and \(secondPartName) at \(secondPartStartBeat)")
                                projectViewModel.updateTrack(at: trackIndex, with: updatedTrack)
                                print("DEBUG: Audio clip split operation complete - created two clips with empty space between them")
                            } else {
                                print("ERROR: Could not find track to update after removing original audio clip")
                            }
                        } else if selStart <= clip.startBeat && selEnd < clip.endBeat {
                            // Selection cuts the beginning - resize and move
                            let newStartBeat = selEnd
                            let newDuration = clip.endBeat - selEnd
                            
                            // Move the clip to the new position
                            _ = audioViewModel?.moveAudioClip(trackId: trackId, clipId: clip.id, newStartBeat: newStartBeat)
                            _ = audioViewModel?.resizeAudioClip(trackId: trackId, clipId: clip.id, newDuration: newDuration)
                        } else if selStart > clip.startBeat && selEnd >= clip.endBeat {
                            // Selection cuts the end - just resize
                            let newDuration = selStart - clip.startBeat
                            _ = audioViewModel?.resizeAudioClip(trackId: trackId, clipId: clip.id, newDuration: newDuration)
                        }
                    }
                    
                    // Clear the selection after processing
                    timelineState.clearSelection()
                }
            }
        }
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
              let trackId = projectViewModel.selectedTrackId,
              let track = projectViewModel.tracks.first(where: { $0.id == trackId }) else {
            return
        }
        
        // Get any multi-selected clips
        let selectedClipIds = timelineState.selectedClipIds
        
        if track.type == .midi {
            // Clear any existing clipboard data
            clipboardAudioClips = nil
            
            // Initialize array to store copied clips
            var clipsToCopy: [(MidiClip, Double, Double)] = []
            
            // Check if we have multi-selected clips
            if !selectedClipIds.isEmpty {
                // Get all selected clips from this track
                let selectedClips = track.midiClips.filter { clip in
                    selectedClipIds.contains(clip.id)
                }
                
                if !selectedClips.isEmpty {
                    // Add all selected clips to clipboard with no offsets
                    for clip in selectedClips {
                        clipsToCopy.append((clip, 0.0, 0.0))
                    }
                    
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("MIDI Clips: \(selectedClips.count)", forType: .string)
                    
                    // Store the copied clips
                    clipboardMidiClips = clipsToCopy
                    return
                }
            }
            
            // If no multi-selection, fall back to the regular selection
            if timelineState.selectionActive {
                // Get the selection range
                let (selStart, selEnd) = timelineState.normalizedSelectionRange
                
                // Get all MIDI clips that overlap with the selection
                let overlappingClips = track.midiClips.filter { clip in
                    // Check if the selection overlaps with this clip
                    selStart < clip.endBeat && selEnd > clip.startBeat
                }
                
                if overlappingClips.isEmpty {
                    // No clips to copy - do nothing and return
                    return
                }
                
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
            }
        } else if track.type == .audio {
            // Clear any existing clipboard data
            clipboardMidiClips = nil
            
            // Initialize array to store copied clips
            var clipsToCopy: [(AudioClip, Double, Double)] = []
            
            // Check if we have multi-selected clips
            if !selectedClipIds.isEmpty {
                // Get all selected clips from this track
                let selectedClips = track.audioClips.filter { clip in
                    selectedClipIds.contains(clip.id)
                }
                
                if !selectedClips.isEmpty {
                    // Add all selected clips to clipboard with no offsets
                    for clip in selectedClips {
                        clipsToCopy.append((clip, 0.0, 0.0))
                    }
                    
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("Audio Clips: \(selectedClips.count)", forType: .string)
                    
                    // Store the copied clips
                    clipboardAudioClips = clipsToCopy
                    return
                }
            }
            
            // If no multi-selection, fall back to the regular selection
            if timelineState.selectionActive {
                // Get the selection range
                let (selStart, selEnd) = timelineState.normalizedSelectionRange
                
                // Get all audio clips that overlap with the selection
                let overlappingClips = track.audioClips.filter { clip in
                    // Check if the selection overlaps with this clip
                    selStart < clip.endBeat && selEnd > clip.startBeat
                }
                
                if overlappingClips.isEmpty {
                    // No clips to copy - do nothing and return
                    return
                }
                
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
                    // Partial clip copy - copy only the notes in the selected range
                    for note in originalClip.notes {
                        // Check if the note is in the copied range
                        let noteStartInClip = note.startBeat
                        let noteEndInClip = noteStartInClip + note.duration
                        let noteStartInSelection = noteStartInClip - startOffset
                        
                        if noteStartInClip >= startOffset && noteEndInClip <= (originalDuration - endOffset) {
                            // Note is fully within the copied range
                            let newNote = MidiNote(
                                pitch: note.pitch,
                                startBeat: noteStartInSelection,
                                duration: note.duration,
                                velocity: note.velocity
                            )
                            newClip.notes.append(newNote)
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
    
    @objc func duplicateSelectedClip() {
        // First copy the selected clips
        copySelectedClip()
        
        // Then paste them right after the existing clips
        guard let projectViewModel = projectViewModel,
              let timelineState = projectViewModel.timelineState,
              let trackId = projectViewModel.selectedTrackId,
              let track = projectViewModel.tracks.first(where: { $0.id == trackId }) else {
            return
        }
        
        // Get any multi-selected clips
        let selectedClipIds = timelineState.selectedClipIds
        
        if !selectedClipIds.isEmpty {
            // Figure out the end beat of the last selected clip
            var lastEndBeat: Double = 0
            
            if track.type == .midi {
                // Get all selected MIDI clips
                let selectedClips = track.midiClips.filter { clip in
                    selectedClipIds.contains(clip.id)
                }
                
                // Find the rightmost end beat
                lastEndBeat = selectedClips.map { $0.endBeat }.max() ?? 0
            } else if track.type == .audio {
                // Get all selected audio clips
                let selectedClips = track.audioClips.filter { clip in
                    selectedClipIds.contains(clip.id)
                }
                
                // Find the rightmost end beat
                lastEndBeat = selectedClips.map { $0.endBeat }.max() ?? 0
            }
            
            if lastEndBeat > 0 {
                // Move the playhead to the end position for pasting
                projectViewModel.seekToBeat(lastEndBeat)
                
                // Now paste the clips
                pasteClip()
                
                return
            }
        }
        
        // If no multi-selection, fall back to regular selection
        if timelineState.selectionActive {
            // Get the selection range to find the end of selected clip
            let (_, selEnd) = timelineState.normalizedSelectionRange
            
            // Move the playhead to the end of the selection
            projectViewModel.seekToBeat(selEnd)
            
            // Paste the clip at the new position
            pasteClip()
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
