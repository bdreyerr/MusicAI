import SwiftUI
import AppKit

/// Coordinator class to handle menu actions for the timeline
class MenuCoordinator: NSObject, ObservableObject {
    weak var projectViewModel: ProjectViewModel?
    var defaultTrackHeight: CGFloat = 100 // Default track height
    
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
              let trackId = timelineState.selectionTrackId,
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
              let trackId = timelineState.selectionTrackId,
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
} 
