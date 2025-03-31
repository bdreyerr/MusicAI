import SwiftUI

/// Shared playhead spanning the timeline height
struct SharedPlayheadView: View {
    @ObservedObject var projectViewModel: ProjectViewModel
    @ObservedObject var state: TimelineStateViewModel
    @EnvironmentObject var themeManager: ThemeManager
    let viewportWidth: CGFloat

    // X-offset based on beat and zoom, relative to the container
    private var xOffset: CGFloat {
        // Calculate absolute position in timeline
        let absoluteX = CGFloat(projectViewModel.currentBeat) * CGFloat(state.effectivePixelsPerBeat)
        // Return position relative to scrolled container
        return absoluteX - state.scrollOffset.x
    }

    // Visibility check using timeline coordinates
    private var isVisible: Bool {
        let playheadAbsoluteX = CGFloat(projectViewModel.currentBeat) * CGFloat(state.effectivePixelsPerBeat)
        let visibleMinX = state.scrollOffset.x
        let visibleMaxX = visibleMinX + viewportWidth
        // Check if the 1-pixel wide playhead intersects the visible rectangle
        return (playheadAbsoluteX + 1 >= visibleMinX) && (playheadAbsoluteX <= visibleMaxX)
    }

    var body: some View {
        // Render only if visible. Note: Hiding during scroll is removed for now.
        // Consider adding !state.isScrolling back if scroll performance degrades.
        if isVisible {
            Rectangle()
                .fill(themeManager.playheadColor)
                .frame(width: 1.0)
                .frame(maxHeight: .infinity) // Span vertically
                .offset(x: xOffset)
                .zIndex(1000) // Ensure it's on top
                // Disable animation during playback for performance
//                .animation(projectViewModel.isPlaying ? nil : .default, value: xOffset) 
        } else {
            EmptyView()
        }
    }
}
