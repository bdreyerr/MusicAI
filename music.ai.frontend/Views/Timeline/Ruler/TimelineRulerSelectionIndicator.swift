import SwiftUI

/// View that displays the current selection on the ruler
struct TimelineRulerSelectionIndicator: View {
    @ObservedObject var state: TimelineStateViewModel
    @ObservedObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var themeManager: ThemeManager
    let height: CGFloat
    
    // Computed properties for the selection visualization
    private var hasSelection: Bool {
        return state.selectionActive
    }
    
    private var selectionRange: (start: Double, end: Double) {
        return state.normalizedSelectionRange
    }
    
    private var startX: CGFloat {
        return CGFloat(selectionRange.start * state.effectivePixelsPerBeat)
    }
    
    private var endX: CGFloat {
        return CGFloat(selectionRange.end * state.effectivePixelsPerBeat)
    }
    
    private var width: CGFloat {
        return endX - startX
    }
    
    var body: some View {
        if hasSelection {
            // Selection rectangle
            Rectangle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: max(1, width), height: height)
                .position(x: startX + width/2, y: height/2)
                .allowsHitTesting(false) // Don't interfere with other gestures
        }
    }
    
    // Format the duration of the selection
    private func formattedDuration() -> String {
        let duration = selectionRange.end - selectionRange.start
        let bars = Int(duration) / projectViewModel.timeSignatureBeats
        let beats = duration.truncatingRemainder(dividingBy: Double(projectViewModel.timeSignatureBeats))
        
        if bars > 0 {
            return "\(bars)b \(String(format: "%.2f", beats))bt"
        } else {
            return "\(String(format: "%.2f", beats))bt"
        }
    }
}

#Preview {
    TimelineRulerSelectionIndicator(
        state: {
            let state = TimelineStateViewModel()
            state.startSelection(at: 4.0, trackId: UUID())
            state.updateSelection(to: 8.0)
            return state
        }(),
        projectViewModel: ProjectViewModel(),
        height: 25
    )
    .environmentObject(ThemeManager())
    .frame(width: 400)
} 
