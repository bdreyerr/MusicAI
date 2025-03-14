import SwiftUI

/// Playhead indicator that shows the current playback position in the timeline
struct PlayheadIndicator: View {
    let currentBeat: Double
    @ObservedObject var state: TimelineState
    let track: Track? // Optional track - if nil, this is the ruler playhead
    @ObservedObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    // Computed property for the x-offset based on current beat and zoom level
    private var xOffset: CGFloat {
        CGFloat(currentBeat) * CGFloat(state.effectivePixelsPerBeat)
    }
    
    var body: some View {
        // Only show the playhead if:
        // 1. This is the ruler playhead (track is nil) - always show the ruler playhead, or
        // 2. Audio is playing - show all playheads, or
        // 3. Audio is paused AND this is the selected track - only show the selected track's playhead
        if track == nil || 
           projectViewModel.isPlaying || 
           (track != nil && projectViewModel.isTrackSelected(track!)) {
            Rectangle()
                .fill(Color.blue)
                .frame(width: 1.0)
                .frame(maxHeight: .infinity)
                // Position the playhead based on the current beat (0-indexed)
                .offset(x: xOffset)
                .zIndex(100)
                // Make the playhead more prominent for the selected track
                .opacity(track != nil && projectViewModel.isTrackSelected(track!) ? 1.0 : 0.8)
                // Animate position changes when zoom level changes
                .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.7), value: state.zoomLevel)
        } else {
            // Return an empty view when the playhead shouldn't be shown
            EmptyView()
        }
    }
}

#Preview {
    PlayheadIndicator(
        currentBeat: 4.0, 
        state: TimelineState(),
        track: Track.samples[0],
        projectViewModel: ProjectViewModel()
    )
    .environmentObject(ThemeManager())
    .frame(height: 200)
} 