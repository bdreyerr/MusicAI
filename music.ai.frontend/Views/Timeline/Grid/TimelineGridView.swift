import SwiftUI

/// Efficiently renders a grid for the entire timeline
/// Uses Canvas for high-performance drawing and only renders visible lines
struct TimelineGridView: View {
    @ObservedObject var state: TimelineStateViewModel
    @ObservedObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var themeManager: ThemeManager
    let width: CGFloat
    let height: CGFloat
    
    // Constants for optimized rendering
    private let viewportMargin: CGFloat = 100 // Extra margin outside viewport to ensure smooth scrolling
    
    // Colors for grid lines - defined once for efficiency
    private var barLineColor: Color { themeManager.gridLineColor.opacity(0.4) }
    private var halfBarLineColor: Color { themeManager.secondaryGridColor.opacity(0.8) }
    private var quarterBarLineColor: Color { themeManager.tertiaryGridColor.opacity(0.8) }
    private var eighthBarLineColor: Color { themeManager.tertiaryGridColor.opacity(0.9) }
    private var sixteenthBarLineColor: Color { themeManager.tertiaryGridColor.opacity(0.7) }
    
    // Reduce contrast for alternating sections
    private var alternatingBgColor: Color { 
        // In light mode, make the dark sections lighter; in dark mode, make the light sections darker
        if themeManager.isDarkMode {
            return Color.gray.opacity(0.08) // Reduced from 0.15 for dark mode
        } else {
            return Color.gray.opacity(0.05) // Reduced from 0.15 for light mode
        }
    }
    
    var body: some View {
        Canvas { context, size in
            // Skip drawing if dimensions are invalid
            guard size.width > 0, size.height > 0 else { return }
            
            // Get current view state
            let scrollX = state.scrollOffset.x
            let pixelsPerBeat = state.effectivePixelsPerBeat
            let beatsPerBar = Double(projectViewModel.timeSignatureBeats)
            let pixelsPerBar = pixelsPerBeat * beatsPerBar
            
            // Calculate visible range with margin
            let startX = max(0, scrollX - viewportMargin)
            let endX = min(
                CGFloat(state.totalBars) * CGFloat(pixelsPerBar),
                scrollX + size.width + viewportMargin
            )
            
            // Draw alternating bar backgrounds
            drawAlternatingBarBackgrounds(
                context: context,
                size: size,
                startX: startX,
                endX: endX,
                pixelsPerBar: pixelsPerBar,
                scrollX: scrollX
            )
            
            // Draw grid lines based on zoom level
            switch state.gridDivision {
            case .sixteenth:
                // Zoom level -1 (future): Draw sixteenth notes
                drawBarLines(context: context, size: size, startX: startX, endX: endX, 
                          pixelsPerBar: pixelsPerBar, scrollX: scrollX)
                drawHalfBarLines(context: context, size: size, startX: startX, endX: endX, 
                              pixelsPerBar: pixelsPerBar, scrollX: scrollX)
                drawQuarterBarLines(context: context, size: size, startX: startX, endX: endX, 
                                 pixelsPerBar: pixelsPerBar, scrollX: scrollX)
                drawEighthBarLines(context: context, size: size, startX: startX, endX: endX, 
                                pixelsPerBar: pixelsPerBar, scrollX: scrollX)
                drawSixteenthBarLines(context: context, size: size, startX: startX, endX: endX,
                                   pixelsPerBar: pixelsPerBar, scrollX: scrollX)
                
            case .eighth:
                // Zoom level 0: Draw eighth notes
                drawBarLines(context: context, size: size, startX: startX, endX: endX, 
                          pixelsPerBar: pixelsPerBar, scrollX: scrollX)
                drawHalfBarLines(context: context, size: size, startX: startX, endX: endX, 
                              pixelsPerBar: pixelsPerBar, scrollX: scrollX)
                drawQuarterBarLines(context: context, size: size, startX: startX, endX: endX, 
                                 pixelsPerBar: pixelsPerBar, scrollX: scrollX)
                drawEighthBarLines(context: context, size: size, startX: startX, endX: endX, 
                                pixelsPerBar: pixelsPerBar, scrollX: scrollX)
                
            case .quarter:
                // Zoom level 1-2: Draw quarter notes (beats)
                drawBarLines(context: context, size: size, startX: startX, endX: endX, 
                          pixelsPerBar: pixelsPerBar, scrollX: scrollX)
                drawHalfBarLines(context: context, size: size, startX: startX, endX: endX, 
                              pixelsPerBar: pixelsPerBar, scrollX: scrollX)
                drawQuarterBarLines(context: context, size: size, startX: startX, endX: endX, 
                                 pixelsPerBar: pixelsPerBar, scrollX: scrollX)
                
            case .half:
                // Zoom level 3-4: Draw half bars
                drawBarLines(context: context, size: size, startX: startX, endX: endX, 
                          pixelsPerBar: pixelsPerBar, scrollX: scrollX)
                drawHalfBarLines(context: context, size: size, startX: startX, endX: endX, 
                              pixelsPerBar: pixelsPerBar, scrollX: scrollX)
                
            case .bar:
                // Zoom level 5-6: Draw only bar lines
                drawBarLines(context: context, size: size, startX: startX, endX: endX, 
                          pixelsPerBar: pixelsPerBar, scrollX: scrollX)
                
            case .twoBar:
                // Draw only every other bar line (for future use)
                drawTwoBarLines(context: context, size: size, startX: startX, endX: endX,
                             pixelsPerBar: pixelsPerBar, scrollX: scrollX)
                
            case .fourBar:
                // Draw only every fourth bar line (for future use)
                drawFourBarLines(context: context, size: size, startX: startX, endX: endX,
                              pixelsPerBar: pixelsPerBar, scrollX: scrollX)
            }
        }
        .frame(width: width, height: height)
        // Use drawingGroup for Metal acceleration, significantly improves performance
        .drawingGroup(opaque: false)
    }
    
    // Draw alternating bar backgrounds based on zoom level
    private func drawAlternatingBarBackgrounds(
        context: GraphicsContext,
        size: CGSize,
        startX: CGFloat,
        endX: CGFloat,
        pixelsPerBar: Double,
        scrollX: CGFloat
    ) {
        // Determine the alternating interval based on zoom level
        let interval = state.gridAlternatingInterval
        
        // Calculate visible bar range
        let startBar = Int(floor(startX / pixelsPerBar))
        let endBar = Int(ceil(endX / pixelsPerBar))
        
        // Create alternating background rectangles
        for barIndex in stride(from: startBar - (startBar % interval), through: endBar, by: interval) {
            // Only color every other group of bars
            if (barIndex / interval) % 2 == 0 {
                let barPosition = Double(barIndex) * pixelsPerBar
                let barWidth = Double(interval) * pixelsPerBar
                
                let barRect = CGRect(
                    x: barPosition - scrollX,
                    y: 0,
                    width: barWidth,
                    height: size.height
                )
                
                // Use the theme manager's alternating background color
                context.fill(Path(barRect), with: .color(themeManager.alternatingGridSectionColor))
            }
        }
    }
    
    // Draw bar lines (1 per bar)
    private func drawBarLines(
        context: GraphicsContext,
        size: CGSize,
        startX: CGFloat,
        endX: CGFloat,
        pixelsPerBar: Double,
        scrollX: CGFloat
    ) {
        // Calculate visible bar range
        let startBar = Int(floor(startX / pixelsPerBar))
        let endBar = Int(ceil(endX / pixelsPerBar))
        
        // Create a path for bar lines
        let path = Path { path in
            for barIndex in startBar...endBar {
                let x = CGFloat(barIndex) * CGFloat(pixelsPerBar) - scrollX
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
        }
        
        // Draw the lines with slightly thinner width due to lower opacity
        context.stroke(path, with: .color(barLineColor), lineWidth: 1.0)
    }
    
    // Draw half-bar lines (2 per bar)
    private func drawHalfBarLines(
        context: GraphicsContext,
        size: CGSize,
        startX: CGFloat,
        endX: CGFloat,
        pixelsPerBar: Double,
        scrollX: CGFloat
    ) {
        // Calculate visible bar range
        let startBar = Int(floor(startX / pixelsPerBar))
        let endBar = Int(ceil(endX / pixelsPerBar))
        
        // Create a path for half-bar lines
        let path = Path { path in
            for barIndex in startBar...endBar {
                // Half-bar position (middle of the bar)
                let x = (CGFloat(barIndex) + 0.5) * CGFloat(pixelsPerBar) - scrollX
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
        }
        
        // Draw the lines with slightly increased width for better visibility with higher opacity
        context.stroke(path, with: .color(halfBarLineColor), lineWidth: 1.0)
    }
    
    // Draw quarter-bar lines (4 per bar)
    private func drawQuarterBarLines(
        context: GraphicsContext,
        size: CGSize,
        startX: CGFloat,
        endX: CGFloat,
        pixelsPerBar: Double,
        scrollX: CGFloat
    ) {
        // Calculate visible bar range
        let startBar = Int(floor(startX / pixelsPerBar))
        let endBar = Int(ceil(endX / pixelsPerBar))
        
        // Create a path for quarter-bar lines (skip positions that have other lines)
        let path = Path { path in
            for barIndex in startBar...endBar {
                // Quarter and three-quarter positions
                let quarters = [0.25, 0.75]
                
                for quarterOffset in quarters {
                    let x = (CGFloat(barIndex) + CGFloat(quarterOffset)) * CGFloat(pixelsPerBar) - scrollX
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                }
            }
        }
        
        // Draw the lines with slightly increased width for better visibility with higher opacity
        context.stroke(path, with: .color(quarterBarLineColor), lineWidth: 0.8)
    }
    
    // Draw eighth-note lines (8 per bar)
    private func drawEighthBarLines(
        context: GraphicsContext,
        size: CGSize,
        startX: CGFloat,
        endX: CGFloat,
        pixelsPerBar: Double,
        scrollX: CGFloat
    ) {
        // Calculate visible bar range
        let startBar = Int(floor(startX / pixelsPerBar))
        let endBar = Int(ceil(endX / pixelsPerBar))
        
        // Create a path for eighth-note lines (skip positions that have other lines)
        let path = Path { path in
            for barIndex in startBar...endBar {
                // Calculate eighth-note positions (skip positions that have other lines)
                let eighths = [0.125, 0.375, 0.625, 0.875]
                
                for eighthOffset in eighths {
                    let x = (CGFloat(barIndex) + CGFloat(eighthOffset)) * CGFloat(pixelsPerBar) - scrollX
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                }
            }
        }
        
        // Draw the eighth-note lines with increased opacity and slightly increased width
        context.stroke(path, with: .color(eighthBarLineColor), lineWidth: 0.7)
    }
    
    // Draw sixteenth-note lines (16 per bar)
    private func drawSixteenthBarLines(
        context: GraphicsContext,
        size: CGSize,
        startX: CGFloat,
        endX: CGFloat,
        pixelsPerBar: Double,
        scrollX: CGFloat
    ) {
        // Calculate visible bar range
        let startBar = Int(floor(startX / pixelsPerBar))
        let endBar = Int(ceil(endX / pixelsPerBar))
        
        // Create a path for sixteenth-note lines (skip positions that have other lines)
        let path = Path { path in
            for barIndex in startBar...endBar {
                // Calculate sixteenth-note positions (skip positions that have other lines)
                let sixteenths = [0.0625, 0.1875, 0.3125, 0.4375, 0.5625, 0.6875, 0.8125, 0.9375]
                
                for sixteenthOffset in sixteenths {
                    let x = (CGFloat(barIndex) + CGFloat(sixteenthOffset)) * CGFloat(pixelsPerBar) - scrollX
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                }
            }
        }
        
        // Draw the sixteenth-note lines with appropriate opacity and width
        context.stroke(path, with: .color(sixteenthBarLineColor), lineWidth: 0.6)
    }
    
    // Draw two-bar grid lines (for future use)
    private func drawTwoBarLines(
        context: GraphicsContext,
        size: CGSize,
        startX: CGFloat,
        endX: CGFloat,
        pixelsPerBar: Double,
        scrollX: CGFloat
    ) {
        // Calculate visible bar range
        let startBar = Int(floor((startX - viewportMargin) / pixelsPerBar))
        let endBar = Int(ceil((endX + viewportMargin) / pixelsPerBar))
        
        // Create a path for two-bar lines
        let path = Path { path in
            for barIndex in stride(from: startBar, through: endBar, by: 2) {
                let x = CGFloat(barIndex) * CGFloat(pixelsPerBar) - scrollX
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
        }
        
        // Draw the lines with the same opacity as regular bar lines
        context.stroke(path, with: .color(barLineColor), lineWidth: 1.0)
    }
    
    // Draw four-bar grid lines (for future use)
    private func drawFourBarLines(
        context: GraphicsContext,
        size: CGSize,
        startX: CGFloat,
        endX: CGFloat,
        pixelsPerBar: Double,
        scrollX: CGFloat
    ) {
        // Calculate visible bar range
        let startBar = Int(floor((startX - viewportMargin) / pixelsPerBar))
        let endBar = Int(ceil((endX + viewportMargin) / pixelsPerBar))
        
        // Create a path for four-bar lines
        let path = Path { path in
            for barIndex in stride(from: startBar, through: endBar, by: 4) {
                let x = CGFloat(barIndex) * CGFloat(pixelsPerBar) - scrollX
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
        }
        
        // Draw the lines with the same opacity as regular bar lines
        context.stroke(path, with: .color(barLineColor), lineWidth: 1.0)
    }
}

#Preview {
    TimelineGridView(
        state: TimelineStateViewModel(),
        projectViewModel: ProjectViewModel(),
        width: 800,
        height: 400
    )
    .environmentObject(ThemeManager())
} 