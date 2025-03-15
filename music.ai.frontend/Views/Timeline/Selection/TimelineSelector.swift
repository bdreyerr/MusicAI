import SwiftUI

/// TimelineSelector handles click/drag interactions for selecting a range on the timeline.
/// It replaces the TimelineScrubber and adds selection functionality.
struct TimelineSelector: View {
    @ObservedObject var projectViewModel: ProjectViewModel
    @ObservedObject var state: TimelineState
    let track: Track
    
    // Computed property to access the MIDI view model
    private var midiViewModel: MidiViewModel {
        return projectViewModel.midiViewModel
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
                        // Convert x position to beat position
                        let xPosition = value.location.x
                        let rawBeatPosition = xPosition / CGFloat(state.effectivePixelsPerBeat)
                        
                        // Ensure we have a valid position (not negative)
                        guard rawBeatPosition >= 0 else { return }
                        
                        // Check if we're clicking on a MIDI clip
                        // If so, the clip itself will handle the selection
                        if track.type == .midi && isPositionOnMidiClip(rawBeatPosition) {
                            print("Drag started on MIDI clip at \(rawBeatPosition), ignoring in TimelineSelector")
                            return
                        }
                        
                        // Snap to the nearest grid marker based on zoom level
                        let snappedBeatPosition = snapToNearestGridMarker(rawBeatPosition)
                        
                        // If this is the start of a drag, begin a new selection
                        if !isDragging {
                            print("Starting new selection at \(snappedBeatPosition) on track \(track.id)")
                            
                            // Select the track
                            projectViewModel.selectTrack(id: track.id)
                            
                            // Check if we need to deselect a MIDI clip first
                            if state.selectionActive && isMidiClipSelected() {
                                state.clearSelection()
                                print("Clearing MIDI clip selection before starting new selection")
                            }
                            
                            // Start a new selection
                            state.startSelection(at: snappedBeatPosition, trackId: track.id)
                            
                            // Move the playhead to the selection start
                            projectViewModel.seekToBeat(snappedBeatPosition)
                            
                            isDragging = true
                        } else {
                            // Update the selection end point
                            state.updateSelection(to: snappedBeatPosition)
                        }
                    }
                    .onEnded { _ in
                        isDragging = false
                        
                        // If the selection is too small (just a click), clear it
                        let (start, end) = state.normalizedSelectionRange
                        if abs(end - start) < 0.001 {
                            state.clearSelection()
                        } else {
                            // Ensure the playhead is at the leftmost point of the selection
                            // This handles the case where the user drags from right to left
                            projectViewModel.seekToBeat(start)
                        }
                    }
            )
            // Clear selection when tapped elsewhere
            .onTapGesture { location in
                // Convert tap location to beat position
                let xPosition = location.x
                let rawBeatPosition = xPosition / CGFloat(state.effectivePixelsPerBeat)
                
                // Ensure we have a valid position (not negative)
                guard rawBeatPosition >= 0 else { return }
                
                // Check if we're clicking on a MIDI clip
                // If so, the clip itself will handle the selection
                if track.type == .midi && isPositionOnMidiClip(rawBeatPosition) {
                    print("Tap detected on MIDI clip at \(rawBeatPosition), ignoring in TimelineSelector")
                    return
                }
                
                // Snap to the nearest grid marker
                let snappedBeatPosition = snapToNearestGridMarker(rawBeatPosition)
                
                // Select the track
                projectViewModel.selectTrack(id: track.id)
                
                // Check if we need to deselect a MIDI clip
                if state.selectionActive && isMidiClipSelected() {
                    state.clearSelection()
                    print("Clearing MIDI clip selection on tap")
                }
                
                // Move the playhead to the clicked position
                projectViewModel.seekToBeat(snappedBeatPosition)
                
                print("Clicked on track at position \(snappedBeatPosition)")
            }
            .allowsHitTesting(true) // Ensure the selector can receive clicks
    }
    
    /// Checks if a MIDI clip is currently selected on this track
    private func isMidiClipSelected() -> Bool {
        return midiViewModel.isMidiClipSelected(trackId: track.id)
    }
    
    /// Checks if a beat position is on a MIDI clip
    private func isPositionOnMidiClip(_ beatPosition: Double) -> Bool {
        return midiViewModel.isPositionOnMidiClip(trackId: track.id, beatPosition: beatPosition)
    }
    
    /// Snaps a raw beat position to the nearest visible grid marker based on the current zoom level
    private func snapToNearestGridMarker(_ rawBeatPosition: Double) -> Double {
        // Determine the smallest visible grid division based on zoom level
        let gridDivision: Double
        
        if state.showSixteenthNotes {
            // Snap to sixteenth notes (0.25 beat)
            gridDivision = 0.25
        } else if state.showEighthNotes {
            // Snap to eighth notes (0.5 beat)
            gridDivision = 0.5
        } else if state.showQuarterNotes {
            // Snap to quarter notes (1 beat)
            gridDivision = 1.0
        } else {
            // When zoomed out all the way, snap to bars
            // For bars, we need to handle differently to ensure we snap to the start of a bar
            let beatsPerBar = Double(projectViewModel.timeSignatureBeats)
            let barIndex = round(rawBeatPosition / beatsPerBar)
            return max(0, barIndex * beatsPerBar) // Ensure we don't go negative
        }
        
        // Calculate the nearest grid marker for beats and smaller divisions
        let nearestGridMarker = round(rawBeatPosition / gridDivision) * gridDivision
        
        return max(0, nearestGridMarker) // Ensure we don't go negative
    }
}

#Preview {
    TimelineSelector(
        projectViewModel: ProjectViewModel(),
        state: TimelineState(),
        track: Track.samples[0]
    )
    .frame(width: 800, height: 100)
} 
