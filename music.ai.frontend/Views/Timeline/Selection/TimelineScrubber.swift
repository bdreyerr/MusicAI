import SwiftUI

/// TimelineScrubber is a transparent overlay that handles click/drag interactions
/// for scrubbing through the timeline. It converts x-position clicks to beat positions.
struct TimelineScrubber: View {
    @ObservedObject var projectViewModel: ProjectViewModel
    @ObservedObject var state: TimelineStateViewModel
    let track: Track? // Optional track - if nil, this is a global scrubber
    
    // State to track the last scrubbed position to avoid unnecessary updates
    @State private var lastScrubbedPosition: Double = -1
    
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
                        
                        // Snap to the nearest grid marker based on zoom level
                        let snappedBeatPosition = snapToNearestGridMarker(rawBeatPosition)
                        
                        // Only update if the position has changed significantly
                        // This prevents unnecessary updates during small movements
                        if abs(snappedBeatPosition - lastScrubbedPosition) > 0.001 {
                            // If this scrubber is associated with a track, select that track
                            if let track = track {
                                projectViewModel.selectTrack(id: track.id)
                            }
                            
                            // Update the playhead position in the project view model
                            projectViewModel.seekToBeat(snappedBeatPosition)
                            lastScrubbedPosition = snappedBeatPosition
                        }
                    }
            )
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
    TimelineScrubber(
        projectViewModel: ProjectViewModel(),
        state: TimelineStateViewModel(),
        track: Track.samples[0]
    )
    .frame(width: 800, height: 100)
} 
