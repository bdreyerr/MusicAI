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
        return max(1, endX - startX)
    }
    
    var body: some View {
        if hasSelection {
            ZStack(alignment: .topLeading) {
                // Selection rectangle
                Rectangle()
                    .fill(themeManager.accentColor.opacity(0.2))
                    .frame(width: width, height: height)
                    .position(x: startX + width/2, y: height/2)
                
                // Selection borders
                Rectangle()
                    .stroke(themeManager.accentColor.opacity(0.7), lineWidth: 1)
                    .frame(width: width, height: height)
                    .position(x: startX + width/2, y: height/2)
            }
            .allowsHitTesting(false) // Don't interfere with other gestures
        }
    }
}
