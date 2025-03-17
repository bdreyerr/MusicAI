import SwiftUI

/// A shared playhead that spans the entire timeline height
/// This replaces individual track playheads for better performance
struct SharedPlayheadView: View {
    @ObservedObject var projectViewModel: ProjectViewModel
    @ObservedObject var state: TimelineStateViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    // Computed property for the x-offset based on current beat and zoom level
    private var xOffset: CGFloat {
        CGFloat(projectViewModel.currentBeat) * CGFloat(state.effectivePixelsPerBeat)
    }
    
    // Check if the playhead is visible in the current viewport
    private var isVisibleInViewport: Bool {
        let scrollX = state.scrollOffset.x
        let viewportWidth = 2000 // Use a large default
        
        // The playhead is visible if it's within the viewport
        return xOffset >= scrollX - 1 && xOffset <= scrollX + CGFloat(viewportWidth) + 1
    }
    
    var body: some View {
        // Only render if visible and not scrolling
        if isVisibleInViewport && !state.isScrolling {
            Rectangle()
                .fill(Color.blue)
                .frame(width: 1.0)
                .frame(maxHeight: .infinity)
                .offset(x: xOffset)
                .zIndex(1000) // Ensure it's above everything else
                // Only animate position changes when NOT playing to improve performance
                .animation(projectViewModel.isPlaying ? nil : .interactiveSpring(response: 0.3, dampingFraction: 0.7), value: state.zoomLevel)
        } else {
            EmptyView()
        }
    }
}

#Preview {
    SharedPlayheadView(
        projectViewModel: ProjectViewModel(),
        state: TimelineStateViewModel()
    )
    .environmentObject(ThemeManager())
    .frame(height: 500)
} 