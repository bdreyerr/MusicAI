import SwiftUI

/// TimelineSelector handles click/drag interactions for selecting a range on the timeline.
/// It replaces the TimelineScrubber and adds selection functionality.
struct TimelineSelector: View {
    @ObservedObject var projectViewModel: ProjectViewModel
    @ObservedObject var state: TimelineStateViewModel
    let track: Track
    
    // Get reference to the interaction manager
    private var interactionManager: InteractionManager {
        return projectViewModel.interactionManager
    }
    
    // Computed property to access the MIDI view model
    private var midiViewModel: MidiViewModel {
        return projectViewModel.midiViewModel
    }
    
    // Computed property to access the Audio view model
    private var audioViewModel: AudioViewModel {
        return projectViewModel.audioViewModel
    }
    
    // State for tracking the drag operation
    @State private var isDragging: Bool = false
    
    var body: some View {
        Rectangle()
            .fill(Color.clear) // Transparent overlay
            .contentShape(Rectangle()) // Make the entire area clickable
            .gesture(
                DragGesture(minimumDistance: 0) // Allow immediate clicks without drag
                    .onChanged { value in
                        // Handle right clicks - show context menu
                        if let event = NSApp.currentEvent, event.type == .rightMouseDown || event.type == .rightMouseDragged || event.type == .rightMouseUp {
                            if event.type == .rightMouseUp {
                                // Let the interaction manager know we're processing a right-click
                                if interactionManager.startRightClick() {
                                    // First select the track
                                    projectViewModel.selectTrack(id: track.id)
                                    
                                    // Convert x position to beat position
                                    let xPosition = value.location.x
                                    let rawBeatPosition = xPosition / CGFloat(state.effectivePixelsPerBeat)
                                    
                                    // Check if we're clicking on a clip
                                    if !((track.type == .midi && isPositionOnMidiClip(rawBeatPosition)) ||
                                         (track.type == .audio && isPositionOnAudioClip(rawBeatPosition))) {
                                        
                                        // Set up selection if there's no existing selection
                                        let snappedBeatPosition = snapToNearestGridMarker(rawBeatPosition)
                                        
                                        if !state.hasSelection(trackId: track.id) {
                                            // If we don't have a selection, create one at the clicked position
                                            state.startSelection(at: snappedBeatPosition, trackId: track.id)
                                            state.updateSelection(to: snappedBeatPosition + 4.0) // Default selection of 4 beats
                                        }
                                    }
                                    
                                    // End the right-click interaction after a short delay
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        interactionManager.endRightClick()
                                    }
                                }
                            }
                            return
                        }
                        
                        // Handle left clicks - for selection and dragging
                        // Convert x position to beat position
                        let xPosition = value.location.x
                        let rawBeatPosition = xPosition / CGFloat(state.effectivePixelsPerBeat)
                        
                        // Ensure we have a valid position (not negative)
                        guard rawBeatPosition >= 0 else { return }
                        
                        // Check if we're clicking on a clip
                        // If so, the clip itself will handle the selection
                        if (track.type == .midi && isPositionOnMidiClip(rawBeatPosition)) ||
                           (track.type == .audio && isPositionOnAudioClip(rawBeatPosition)) {
                            // print("⚠️ TIMELINE SELECTOR: Drag started on clip at \(rawBeatPosition), ignoring in TimelineSelector")
                            return
                        }
                        
                        // print("✅ TIMELINE SELECTOR: Drag detected at \(rawBeatPosition), not on a clip")
                        
                        // Check if we can start a selection with the interaction manager
                        if !isDragging && !interactionManager.canStartSelection() {
                            // Cannot start selection due to another active interaction
                            return
                        }
                        
                        // Snap to the nearest grid marker based on zoom level
                        let snappedBeatPosition = snapToNearestGridMarker(rawBeatPosition)
                        
                        // If this is the start of a drag, begin a new selection
                        if !isDragging {
                            // Ask the interaction manager if we can start a selection
                            if interactionManager.startSelection() {
                                // print("✅ TIMELINE SELECTOR: Starting new selection at \(snappedBeatPosition) on track \(track.id)")
                                
                                // Select the track
                                projectViewModel.selectTrack(id: track.id)
                                
                                // Check if we need to deselect a clip first
                                if state.selectionActive && isClipSelected() {
                                    state.clearSelection()
                                    // print("✅ TIMELINE SELECTOR: Clearing clip selection before starting new selection")
                                }
                                
                                // Start a new selection
                                state.startSelection(at: snappedBeatPosition, trackId: track.id)
                                
                                // Move the playhead to the selection start
                                projectViewModel.seekToBeat(snappedBeatPosition)
                                
                                isDragging = true
                            }
                        } else {
                            // Update the selection end point
                            state.updateSelection(to: snappedBeatPosition)
                            // print("✅ TIMELINE SELECTOR: Updating selection to \(snappedBeatPosition)")
                        }
                    }
                    .onEnded { value in
                        // Ignore right clicks
                        guard let event = NSApp.currentEvent, event.type != .rightMouseUp else {
                            return
                        }
                        
                        // Only process if we were actively dragging
                        if isDragging {
                            isDragging = false
                            
                            // Let the interaction manager know we're done with the selection
                            interactionManager.endSelection()
                            
                            // If the selection is too small (just a click), clear it
                            let (start, end) = state.normalizedSelectionRange
                            if abs(end - start) < 0.001 {
                                state.clearSelection()
                                // print("✅ TIMELINE SELECTOR: Selection too small, clearing")
                            } else {
                                // Ensure the playhead is at the leftmost point of the selection
                                // This handles the case where the user drags from right to left
                                projectViewModel.seekToBeat(start)
                                // print("✅ TIMELINE SELECTOR: Selection completed: \(start) to \(end)")
                            }
                        }
                    }
            )
            // Handle taps to move the playhead without stopping playback
            .onTapGesture { location in
                // Check if we can process this tap (don't process if another interaction is active)
                if !interactionManager.canStartSelection() {
                    return
                }
                
                // Convert tap location to beat position
                let xPosition = location.x
                let rawBeatPosition = xPosition / CGFloat(state.effectivePixelsPerBeat)
                
                // Ensure we have a valid position (not negative)
                guard rawBeatPosition >= 0 else { return }
                
                // Check if we're clicking on a clip
                // If so, the clip itself will handle the selection
                if (track.type == .midi && isPositionOnMidiClip(rawBeatPosition)) ||
                   (track.type == .audio && isPositionOnAudioClip(rawBeatPosition)) {
                    // print("Tap detected on clip at \(rawBeatPosition), ignoring in TimelineSelector")
                    return
                }
                
                // Snap to the nearest grid marker
                let snappedBeatPosition = snapToNearestGridMarker(rawBeatPosition)
                
                // Select the track
                projectViewModel.selectTrack(id: track.id)
                
                // Check if we need to deselect a clip
                if state.selectionActive && isClipSelected() {
                    state.clearSelection()
                    // print("Clearing clip selection on tap")
                }
                
                // Move the playhead to the clicked position
                // The seekToBeat function now handles playback state internally
                projectViewModel.seekToBeat(snappedBeatPosition)
                
                // print("Clicked on track at position \(snappedBeatPosition)")
            }
            .allowsHitTesting(true) // Ensure the selector can receive clicks
    }
    
    /// Checks if a clip is currently selected on this track
    private func isClipSelected() -> Bool {
        if track.type == .midi {
            return midiViewModel.isMidiClipSelected(trackId: track.id)
        } else if track.type == .audio {
            return audioViewModel.isAudioClipSelected(trackId: track.id)
        }
        return false
    }
    
    /// Checks if a beat position is on a MIDI clip
    private func isPositionOnMidiClip(_ beatPosition: Double) -> Bool {
        return midiViewModel.isPositionOnMidiClip(trackId: track.id, beatPosition: beatPosition)
    }
    
    /// Checks if a beat position is on an audio clip
    private func isPositionOnAudioClip(_ beatPosition: Double) -> Bool {
        return audioViewModel.isPositionOnAudioClip(trackId: track.id, beatPosition: beatPosition)
    }
    
    /// Snaps a raw beat position to the nearest visible grid marker based on the current zoom level
    private func snapToNearestGridMarker(_ rawBeatPosition: Double) -> Double {
        // Determine the smallest visible grid division based on zoom level
        let timeSignature = projectViewModel.timeSignatureBeats
        
        switch state.gridDivision {
        case .sixteenth, .eighth:
            // Snap to eighth notes (0.125 beat)
            return round(rawBeatPosition * 8.0) / 8.0
            
        case .quarter:
            // Snap to quarter notes (0.25 beat)
            return round(rawBeatPosition * 4.0) / 4.0
            
        case .half:
            // For half-bar markers (assuming 4/4 time, this would be beat 2)
            let beatsPerBar = Double(timeSignature)
            
            // Calculate the bar index and position within the bar
            let barIndex = floor(rawBeatPosition / beatsPerBar)
            let positionInBar = rawBeatPosition - (barIndex * beatsPerBar)
            
            // Check if we're closer to the start of the bar, middle of the bar, or end of the bar
            if positionInBar < beatsPerBar / 4.0 {
                // Snap to start of bar
                return barIndex * beatsPerBar
            } else if positionInBar > (beatsPerBar * 3.0) / 4.0 {
                // Snap to start of next bar
                return (barIndex + 1) * beatsPerBar
            } else {
                // Snap to half-bar
                return barIndex * beatsPerBar + beatsPerBar / 2.0
            }
            
        case .bar, .twoBar, .fourBar:
            // When zoomed out, snap to bars
            let beatsPerBar = Double(timeSignature)
            return round(rawBeatPosition / beatsPerBar) * beatsPerBar
        }
    }
}

#Preview {
    TimelineSelector(
        projectViewModel: ProjectViewModel(),
        state: TimelineStateViewModel(),
        track: Track.samples[0]
    )
    .frame(width: 800, height: 100)
} 
