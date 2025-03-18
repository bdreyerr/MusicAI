import SwiftUI

/// A shared grid that displays horizontal timing lines for all tracks
/// Renders a single grid for the entire timeline to improve performance
struct SharedGridView: View {
    @ObservedObject var state: TimelineStateViewModel
    @ObservedObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var themeManager: ThemeManager
    let width: CGFloat
    let height: CGFloat
    
    // Performance optimization constants
    private let viewportMargin: CGFloat = 20
    private let maxBarCount = 1000 // Safety limit for rendering
    
    // Performance tracking for scroll-based rendering
    @State private var lastRenderScrollX: CGFloat = 0
    @State private var scrollRenderThreshold: CGFloat = 10
    
    // Local color constants for grid lines
    private var barLineColor: Color { themeManager.gridLineColor }
    private var beatLineColor: Color { themeManager.secondaryGridColor }
    private var eighthLineColor: Color { themeManager.tertiaryGridColor }
    private var sixteenthLineColor: Color { themeManager.tertiaryGridColor.opacity(0.5) }
    
    var body: some View {
        Canvas { context, size in
            // Only attempt to draw if we have valid dimensions
            guard size.width > 0, size.height > 0 else { return }
            
            // Draw the grid lines
            drawGridLines(context: context, size: size)
            
            // Mark the last position we rendered
            // Do not modify state during rendering - handled by onChange instead
            // lastRenderScrollX = scrollX  // This would cause the "modifying state during view update" error
            
        }
        .frame(width: width, height: height)
        // Use safer ID approach that doesn't directly call methods during rendering
        .id("grid-zoom-\(state.zoomLevel)-scrolling-\(state.isScrolling ? "yes" : "no")")
        // Use proper onChange syntax for macOS 14.0
        .onChange(of: state.scrollOffset) { _, newValue in
            // Safely update lastRenderScrollX using async to avoid "modifying state during view update" errors
            DispatchQueue.main.async {
                self.lastRenderScrollX = newValue.x
            }
        }
        .drawingGroup(opaque: false) // Use Metal acceleration
    }
    
    func drawGridLines(context: GraphicsContext, size: CGSize) {
        let scrollX = state.scrollOffset.x
        let projectDuration = Double(projectViewModel.durationInBeats)
        let viewportWidth = size.width
        
        // Capture state values locally to avoid direct state access during rendering
        let currentZoomLevel = state.zoomLevel
        let isCurrentlyScrolling = state.isScrolling
        let currentScrollingSpeed = state.scrollingSpeed
        let shouldRenderInnerGrid = currentZoomLevel <= 6 // Determine based on zoom level instead of non-existent property
        
        // Calculate the visible range based on scroll position
        let startX = max(0, scrollX - viewportMargin)
        let endX = min(projectDuration * state.pixelsPerBeat, scrollX + viewportWidth + viewportMargin)
        
        // Major grid lines (bar lines)x
        let barPath = Path { path in
            var barNumber = Int(startX / (4 * state.pixelsPerBeat))
            
            while Double(barNumber * 4) * state.pixelsPerBeat <= endX {
                let x = Double(barNumber * 4) * state.pixelsPerBeat - scrollX
                if x >= -1 && x <= viewportWidth + 1 {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                }
                barNumber += 1
            }
        }
        context.stroke(barPath, with: .color(barLineColor), lineWidth: 1)
        
        // Inner grid lines (beats, quarter beats, etc.)
        if shouldRenderInnerGrid {
            // Determine detail level based on zoom
            let skipFactor = getSkipFactor(zoomLevel: currentZoomLevel, isScrolling: isCurrentlyScrolling, scrollingSpeed: currentScrollingSpeed)
            
            // Paths for different types of grid lines
            let beatPath = Path { path in
                var beat = Int(startX / state.pixelsPerBeat)
                
                while Double(beat) * state.pixelsPerBeat <= endX {
                    let x = Double(beat) * state.pixelsPerBeat - scrollX
                    
                    if x >= -1 && x <= viewportWidth + 1 {
                        // Only draw if it's not a bar line (every 4th beat)
                        if beat % 4 != 0 {
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: size.height))
                        }
                    }
                    
                    beat += 1
                }
            }
            context.stroke(beatPath, with: .color(beatLineColor), lineWidth: 0.5)
            
            // Eighth notes
            if skipFactor <= 1 {
                let eighthPath = Path { path in
                    var eighth = Int(startX / (state.pixelsPerBeat / 2)) 
                    
                    while Double(eighth) * (state.pixelsPerBeat / 2) <= endX {
                        let x = Double(eighth) * (state.pixelsPerBeat / 2) - scrollX
                        
                        if x >= -1 && x <= viewportWidth + 1 {
                            // Only draw if it's not a beat line (every 2nd eighth)
                            if eighth % 2 != 0 {
                                path.move(to: CGPoint(x: x, y: 0))
                                path.addLine(to: CGPoint(x: x, y: size.height))
                            }
                        }
                        
                        eighth += 1
                    }
                }
                context.stroke(eighthPath, with: .color(eighthLineColor), lineWidth: 0.5)
            }
            
            // Sixteenth notes 
            if skipFactor == 0 && currentZoomLevel >= 4 {
                let sixteenthPath = Path { path in
                    var sixteenth = Int(startX / (state.pixelsPerBeat / 4))
                    
                    while Double(sixteenth) * (state.pixelsPerBeat / 4) <= endX {
                        let x = Double(sixteenth) * (state.pixelsPerBeat / 4) - scrollX
                        
                        if x >= -1 && x <= viewportWidth + 1 {
                            // Only draw if it's not an eighth line (every 2nd sixteenth)
                            if sixteenth % 2 != 0 {
                                path.move(to: CGPoint(x: x, y: 0))
                                path.addLine(to: CGPoint(x: x, y: size.height))
                            }
                        }
                        
                        sixteenth += 1
                    }
                }
                context.stroke(sixteenthPath, with: .color(sixteenthLineColor), lineWidth: 0.2)
            }
        }
    }
    
    // Helper function to determine how much detail to skip based on zoom level and scrolling speed
    private func getSkipFactor(zoomLevel: Int, isScrolling: Bool, scrollingSpeed: CGFloat) -> Int {
        if !isScrolling || scrollingSpeed < 300 {
            // Not scrolling or scrolling slowly - show full detail based on zoom
            return zoomLevel >= 3 ? 0 : (zoomLevel >= 2 ? 1 : 2)
        } else if scrollingSpeed < 1000 {
            // Medium speed scrolling - reduce detail slightly
            return zoomLevel >= 4 ? 1 : 2
        } else {
            // Fast scrolling - minimal detail
            return 2
        }
    }
}

#Preview {
    SharedGridView(
        state: TimelineStateViewModel(),
        projectViewModel: ProjectViewModel(),
        width: 800,
        height: 400
    )
    .environmentObject(ThemeManager())
} 
