import SwiftUI

/// Overlay view that displays the current selection range on a track
struct TimelineSelectionOverlay: View {
    @ObservedObject var state: TimelineStateViewModel
    @ObservedObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var themeManager: ThemeManager
    let track: Track? // Optional track parameter
    
    // Computed properties for the selection range
    private var selectionStartX: CGFloat {
        CGFloat(state.selectionStartBeat) * CGFloat(state.effectivePixelsPerBeat)
    }
    
    private var selectionEndX: CGFloat {
        CGFloat(state.selectionEndBeat) * CGFloat(state.effectivePixelsPerBeat)
    }
    
    // Get the normalized selection range (start always less than end)
    private var normalizedRange: (start: CGFloat, end: CGFloat) {
        if selectionStartX <= selectionEndX {
            return (selectionStartX, selectionEndX)
        } else {
            return (selectionEndX, selectionStartX)
        }
    }
    
    // Calculate the width of the selection
    private var selectionWidth: CGFloat {
        let (start, end) = normalizedRange
        return max(2, end - start) // Ensure minimum width for visibility
    }
    
    // Check if selection should be shown for this track
    private var shouldShowSelection: Bool {
        if let track = track {
            // If track is provided, only show selection if it's for this track
            return state.selectionActive && state.selectionTrackId == track.id
        } else {
            // If no track is provided (e.g., for ruler), show selection if any is active
            return state.selectionActive
        }
    }
    
    var body: some View {
        if shouldShowSelection {
            let (start, _) = normalizedRange
            
            Rectangle()
                .fill(themeManager.accentColor.opacity(0.3))
                .frame(width: selectionWidth)
                .frame(maxHeight: .infinity)
                .offset(x: start)
                .overlay(
                    Rectangle()
                        .stroke(themeManager.accentColor, lineWidth: 1.5)
                        .frame(width: selectionWidth)
                        .frame(maxHeight: .infinity)
                        .offset(x: start)
                )
                .allowsHitTesting(false) // Don't block interactions
                .id("selection-\(state.selectionStartBeat)-\(state.selectionEndBeat)") // Force redraw when selection changes
        } else {
            // Return an empty view when no selection should be shown
            Color.clear
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
        }
    }
}

#Preview {
    TimelineSelectionOverlay(
        state: {
            let state = TimelineStateViewModel()
            state.selectionActive = true
            state.selectionStartBeat = 4.0
            state.selectionEndBeat = 8.0
            state.selectionTrackId = UUID()
            return state
        }(),
        projectViewModel: ProjectViewModel(),
        track: Track.samples[0]
    )
    .environmentObject(ThemeManager())
    .frame(width: 500, height: 100)
    .background(Color.gray.opacity(0.2))
} 