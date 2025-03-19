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

//#Preview {
//    TimelineScrubber(
//        projectViewModel: ProjectViewModel(),
//        state: TimelineStateViewModel(),
//        track: Track.samples[0]
//    )
//    .frame(width: 800, height: 100)
//} 
