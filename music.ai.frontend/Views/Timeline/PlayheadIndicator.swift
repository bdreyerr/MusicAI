import SwiftUI

/// Playhead indicator that shows the current playback position in the timeline
struct PlayheadIndicator: View {
    let currentBeat: Double
    let state: TimelineState
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Rectangle()
            .fill(Color.red)
            .frame(width: 2)
            .frame(maxHeight: .infinity)
            // Position the playhead based on the current beat (0-indexed)
            .offset(x: CGFloat(currentBeat) * CGFloat(state.effectivePixelsPerBeat))
            .zIndex(100)
    }
}

#Preview {
    PlayheadIndicator(currentBeat: 4.0, state: TimelineState())
        .environmentObject(ThemeManager())
        .frame(height: 200)
} 