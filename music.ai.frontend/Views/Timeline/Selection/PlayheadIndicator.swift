import SwiftUI

/// Playhead indicator that shows the current playback position in the timeline
/// Now used only for the ruler playhead
struct PlayheadIndicator: View {
    let currentBeat: Double
    @ObservedObject var state: TimelineStateViewModel
    @ObservedObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    // Computed property for the x-offset based on current beat and zoom level
    private var xOffset: CGFloat {
        CGFloat(currentBeat) * CGFloat(state.effectivePixelsPerBeat)
    }
    
    // Check if the playhead is visible in the current viewport
    private var isVisibleInViewport: Bool {
        let scrollX = state.scrollOffset.x
        let viewportWidth = 2000 // Use a large default
        
        // The playhead is visible if it's within the viewport
        return xOffset >= scrollX - 1 && xOffset <= scrollX + CGFloat(viewportWidth) + 1
    }
    
    var body: some View {
        // Simple conditional rendering
        if isVisibleInViewport {
            Rectangle()
                .fill(themeManager.playheadColor)
                .frame(width: 1.0)
                .frame(maxHeight: .infinity)
                .offset(x: xOffset)
                .zIndex(100) // Ensure it's above everything else
                // Only animate position changes when NOT playing to improve performance
                .animation(projectViewModel.isPlaying ? nil : .interactiveSpring(response: 0.3, dampingFraction: 0.7), value: state.zoomLevel)
        } else {
            // Return an empty view when the playhead shouldn't be shown
            EmptyView()
        }
    }
}

#Preview {
    PlayheadIndicator(
        currentBeat: 4.0, 
        state: TimelineStateViewModel(),
        projectViewModel: ProjectViewModel()
    )
    .environmentObject(ThemeManager())
    .frame(height: 200)
} 
