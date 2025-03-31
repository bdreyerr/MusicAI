import SwiftUI

/// Playhead indicator for the ruler
struct PlayheadIndicator: View {
    let currentBeat: Double
    @ObservedObject var state: TimelineStateViewModel
    @ObservedObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var themeManager: ThemeManager
    let viewportWidth: CGFloat

    // X-offset based on beat and zoom
    private var xOffset: CGFloat {
        CGFloat(currentBeat) * CGFloat(state.effectivePixelsPerBeat) - state.scrollOffset.x
    }

    // Visibility check
    private var isVisible: Bool {
        let viewMinX = CGFloat(currentBeat) * CGFloat(state.effectivePixelsPerBeat)
        let viewMaxX = viewMinX + 1 // Playhead width is 1
        let visibleRect = CGRect(x: state.scrollOffset.x, y: 0, width: viewportWidth, height: 1) // Height doesn't matter here
        let viewRect = CGRect(x: viewMinX, y: 0, width: 1, height: 1)
        return visibleRect.intersects(viewRect)
    }

    var body: some View {
        if isVisible {
            Rectangle()
                .fill(themeManager.playheadColor)
                .frame(width: 1.0)
                .frame(maxHeight: .infinity)
                .offset(x: xOffset)
                .zIndex(100)
                // No animation during playback
                .animation(projectViewModel.isPlaying ? nil : .default, value: xOffset)
        } else {
            EmptyView()
        }
    }
}
