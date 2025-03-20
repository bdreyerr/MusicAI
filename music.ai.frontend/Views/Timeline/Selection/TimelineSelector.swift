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
    @State private var dragStartPoint: CGPoint? = nil
    @State private var lastClickTime: Date = Date(timeIntervalSince1970: 0)
    
    var body: some View {
        Rectangle()
            .fill(Color.clear) // Transparent overlay
            .contentShape(Rectangle()) // Make the entire area clickable
            .gesture(
                // Use a single DragGesture to handle both clicks and drags
                DragGesture(minimumDistance: 0) // Allow immediate recognition
                    .onChanged { value in
                        // Check for right-click interactions
                        if let event = NSApp.currentEvent, event.type == .rightMouseDown || event.type == .rightMouseDragged || event.type == .rightMouseUp {
                            // Handle right-clicks
                            handleRightClick(value: value, event: event)
                            return
                        }
                        
                        // Convert position to beat position
                        let xPosition = value.location.x
                        let rawBeatPosition = xPosition / CGFloat(state.effectivePixelsPerBeat)
                        
                        // Ensure valid position
                        guard rawBeatPosition >= 0 else { return }
                        
                        // Snap to nearest grid marker
                        let snappedBeatPosition = snapToNearestGridMarker(rawBeatPosition)
                        
                        // If this is the start of the gesture, determine if it should be a tap or a drag
                        if dragStartPoint == nil {
                            dragStartPoint = value.location
                            
                            // If the interaction manager currently has an active selection,
                            // force reset it to ensure we can start a new one
                            if !interactionManager.canStartSelection() {
                                interactionManager.resetAll()
                            }
                            
                            // Select the track
                            projectViewModel.selectTrack(id: track.id)
                            
                            // Check if this should initiate a drag (selection) or just be treated as a tap
                            // For now, always consider it a potential drag, we'll decide later
                            if interactionManager.startSelection() {
                                // Clear any existing clip selection if needed
                                if state.selectionActive && isClipSelected() {
                                    DispatchQueue.main.async {
                                        state.clearSelection()
                                    }
                                }
                                
                                // Start selection at this point - now we allow selection to start
                                // even on clips
                                state.startSelection(at: snappedBeatPosition, trackId: track.id)
                                
                                // Move playhead to selection start
                                projectViewModel.seekToBeat(snappedBeatPosition)
                                
                                isDragging = true
                            }
                        } else if isDragging {
                            // We have a drag start point and are in dragging mode, update selection
                            let dragDistance = abs(value.location.x - (dragStartPoint?.x ?? 0))
                            
                            // Only update the selection if we've moved a meaningful amount
                            // This helps distinguish between clicks and actual drags
                            if dragDistance > 5 { // 5 pixels threshold
                                // Update the selection to the current position
                                // We always update to wherever the mouse is
                                state.updateSelection(to: snappedBeatPosition)
                            }
                        }
                    }
                    .onEnded { value in
                        // Ignore right-clicks
                        guard let event = NSApp.currentEvent, event.type != .rightMouseUp else {
                            dragStartPoint = nil
                            return
                        }
                        
                        // Process only if we have a start point
                        if let startPoint = dragStartPoint {
                            // Reset the drag start point
                            dragStartPoint = nil
                            
                            // Check if this was a drag or just a click
                            let dragDistance = abs(value.location.x - startPoint.x)
                            let wasJustAClick = dragDistance < 5 // Less than 5 pixels movement
                            
                            if isDragging {
                                isDragging = false
                                
                                // End the selection interaction
                                interactionManager.endSelection()
                                
                                // Get the selection range
                                let (start, end) = state.normalizedSelectionRange
                                
                                if wasJustAClick || abs(end - start) < 0.001 {
                                    // This was just a click or a tiny selection, treat it as a tap
                                    // Clear the selection
                                    DispatchQueue.main.async {
                                        state.clearSelection()
                                    }
                                    
                                    // Calculate beat position for the tap
                                    let xPosition = value.location.x
                                    let rawBeatPosition = xPosition / CGFloat(state.effectivePixelsPerBeat)
                                    let snappedBeatPosition = snapToNearestGridMarker(rawBeatPosition)
                                    
                                    // Move the playhead
                                    projectViewModel.seekToBeat(snappedBeatPosition)
                                } else {
                                    // This was a real selection, ensure playhead is at start
                                    DispatchQueue.main.async {
                                        projectViewModel.seekToBeat(start)
                                    }
                                }
                            }
                        }
                        
                        // Always ensure interaction state is clean after gesture ends
                        DispatchQueue.main.async {
                            if isDragging {
                                isDragging = false
                                interactionManager.endSelection()
                            } else {
                                interactionManager.resetAll()
                            }
                        }
                    }
            )
            .allowsHitTesting(true) // Ensure the selector can receive clicks
    }
    
    /// Handle right-click interactions
    private func handleRightClick(value: DragGesture.Value, event: NSEvent) {
        if event.type == .rightMouseUp {
            // Let the interaction manager know we're processing a right-click
            if interactionManager.startRightClick() {
                // First select the track
                projectViewModel.selectTrack(id: track.id)
                
                // Convert x position to beat position
                let xPosition = value.location.x
                let rawBeatPosition = xPosition / CGFloat(state.effectivePixelsPerBeat)
                
                // Set up selection if there's no existing selection
                let snappedBeatPosition = snapToNearestGridMarker(rawBeatPosition)
                
                if !state.hasSelection(trackId: track.id) {
                    // If we don't have a selection, create one at the clicked position
                    state.startSelection(at: snappedBeatPosition, trackId: track.id)
                    
                    // Check if we're clicking within a clip
                    if track.type == .midi, let clip = midiViewModel.getMidiClipAt(trackId: track.id, beatPosition: snappedBeatPosition) {
                        // If right-clicking on a clip, default to selecting a 1-beat region
                        // or the remaining part of the clip, whichever is smaller
                        let remainingClipBeats = clip.endBeat - snappedBeatPosition
                        let selectionSize = min(1.0, remainingClipBeats)
                        state.updateSelection(to: snappedBeatPosition + selectionSize)
                    } else if track.type == .audio, let clip = audioViewModel.getAudioClipAt(trackId: track.id, beatPosition: snappedBeatPosition) {
                        // If right-clicking on a clip, default to selecting a 1-beat region
                        // or the remaining part of the clip, whichever is smaller
                        let remainingClipBeats = clip.endBeat - snappedBeatPosition
                        let selectionSize = min(1.0, remainingClipBeats)
                        state.updateSelection(to: snappedBeatPosition + selectionSize)
                    } else {
                        // Default selection of 4 beats if not on a clip
                        state.updateSelection(to: snappedBeatPosition + 4.0)
                    }
                }
                
                // End the right-click interaction after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    interactionManager.endRightClick()
                }
            }
        }
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
        case .sixteenth:
            // Snap to sixteenth notes (0.0625 beat)
            return round(rawBeatPosition * 16.0) / 16.0
            
        case .eighth:
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
            
        case .bar:
            // When zoomed out, snap to bars
            let beatsPerBar = Double(timeSignature)
            return round(rawBeatPosition / beatsPerBar) * beatsPerBar
            
        case .twoBar:
            // When zoomed way out, snap to every two bars
            let beatsPerTwoBars = Double(timeSignature) * 2.0
            return round(rawBeatPosition / beatsPerTwoBars) * beatsPerTwoBars
            
        case .fourBar:
            // When zoomed way out, snap to every four bars
            let beatsPerFourBars = Double(timeSignature) * 4.0
            return round(rawBeatPosition / beatsPerFourBars) * beatsPerFourBars
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
