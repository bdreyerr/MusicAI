import SwiftUI

/// SharedGridView renders the timeline grid once and is shared across all tracks
/// This improves performance by avoiding duplicate grid calculations for each track
struct SharedGridView: View {
    @ObservedObject var state: TimelineStateViewModel
    @ObservedObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var themeManager: ThemeManager
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        Canvas { context, size in
            // Calculate grid dimensions
            let pixelsPerBeat = state.effectivePixelsPerBeat
            let beatsPerBar = Double(projectViewModel.timeSignatureBeats)
            let pixelsPerBar = pixelsPerBeat * beatsPerBar
            
            // Calculate visible range based on scroll offset
            let scrollX = state.scrollOffset.x
            let startX = scrollX
            let endX = startX + size.width
            
            // Calculate the visible bar range
            let startBar = max(0, Int(floor(startX / CGFloat(pixelsPerBar))))
            
            // Calculate the maximum bar index based on content width
            let maxBarIndex = Int(ceil(width / CGFloat(pixelsPerBar)))
            let endBar = min(maxBarIndex, Int(ceil(endX / CGFloat(pixelsPerBar))) + 1)
            
            // Draw alternating section backgrounds based on the grid alternating interval
            drawAlternatingBackgrounds(context: context, 
                                       size: size, 
                                       startBar: startBar, 
                                       endBar: endBar, 
                                       pixelsPerBar: pixelsPerBar)
            
            // Draw grid lines based on zoom level
            switch state.gridDivision {
            case .fourBar, .twoBar, .bar:
                // Show grid lines at each bar
                drawBarLines(context: context, 
                             size: size, 
                             startBar: startBar, 
                             endBar: endBar, 
                             pixelsPerBar: pixelsPerBar, 
                             scrollX: scrollX, 
                             endX: endX)
                
            case .half:
                // Show grid lines at bars and half-bars
                drawHalfBarLines(context: context, 
                                 size: size, 
                                 startBar: startBar, 
                                 endBar: endBar, 
                                 pixelsPerBar: pixelsPerBar, 
                                 pixelsPerBeat: pixelsPerBeat, 
                                 scrollX: scrollX, 
                                 endX: endX)
                
            case .quarter:
                // Show grid lines at each quarter bar (each beat in 4/4)
                drawQuarterBarLines(context: context, 
                                    size: size, 
                                    startBar: startBar, 
                                    endBar: endBar, 
                                    pixelsPerBar: pixelsPerBar, 
                                    pixelsPerBeat: pixelsPerBeat, 
                                    scrollX: scrollX, 
                                    endX: endX)
                
            case .eighth, .sixteenth:
                // Show grid lines at each eighth bar
                drawEighthBarLines(context: context, 
                                   size: size, 
                                   startBar: startBar, 
                                   endBar: endBar, 
                                   pixelsPerBar: pixelsPerBar, 
                                   pixelsPerBeat: pixelsPerBeat, 
                                   scrollX: scrollX, 
                                   endX: endX)
            }
        }
        .drawingGroup(opaque: false) // Use Metal acceleration for better performance
    }
    
    // MARK: - Grid Drawing Methods
    
    // Draw alternating background sections based on the grid alternating interval
    private func drawAlternatingBackgrounds(context: GraphicsContext, size: CGSize, 
                                           startBar: Int, endBar: Int, pixelsPerBar: Double) {
        // Get the interval from the state
        let alternatingInterval = state.gridAlternatingInterval
        
        // Adjust start bar to the nearest interval boundary
        let adjustedStartBar = (startBar / alternatingInterval) * alternatingInterval
        
        // Draw alternating colored sections
        for sectionStartBar in stride(from: adjustedStartBar, to: endBar + alternatingInterval, by: alternatingInterval) {
            // Determine if this section should be colored (alternating pattern)
            let shouldColor = (sectionStartBar / alternatingInterval) % 2 == 1
            
            if shouldColor {
                // Calculate section bounds
                let sectionStart = CGFloat(Double(sectionStartBar) * pixelsPerBar)
                let sectionWidth = CGFloat(Double(alternatingInterval) * pixelsPerBar)
                
                // Create and fill the rectangle
                let rect = CGRect(x: sectionStart, y: 0, width: sectionWidth, height: size.height)
                let path = Path(rect)
                
                context.fill(path, with: .color(themeManager.alternatingGridSectionColor))
                
                // Draw border for the section
                context.stroke(
                    path,
                    with: .color(themeManager.secondaryBorderColor),
                    lineWidth: 0.5
                )
            }
        }
    }
    
    // Draw grid lines at bar boundaries (for zoom levels 5-6)
    private func drawBarLines(context: GraphicsContext, size: CGSize, 
                             startBar: Int, endBar: Int, pixelsPerBar: Double, 
                             scrollX: CGFloat, endX: CGFloat) {
        // Draw a vertical line at each bar
        for barIndex in stride(from: startBar, to: endBar, by: 1) {
            let xPosition = CGFloat(Double(barIndex) * pixelsPerBar)
            
            // Skip if outside viewport with a small margin
            if xPosition < scrollX - 1 || xPosition > scrollX + size.width + 1 {
                continue
            }
            
            // Draw the bar line
            var path = Path()
            path.move(to: CGPoint(x: xPosition, y: 0))
            path.addLine(to: CGPoint(x: xPosition, y: size.height))
            
            context.stroke(
                path,
                with: .color(themeManager.gridLineColor.opacity(0.7)),
                lineWidth: 0.5
            )
        }
    }
    
    // Draw grid lines at bar and half-bar positions (for zoom levels 3-4)
    private func drawHalfBarLines(context: GraphicsContext, size: CGSize, 
                                 startBar: Int, endBar: Int, pixelsPerBar: Double, pixelsPerBeat: Double,
                                 scrollX: CGFloat, endX: CGFloat) {
        let timeSignature = projectViewModel.timeSignatureBeats
        
        // First draw bar lines
        drawBarLines(context: context, size: size, startBar: startBar, endBar: endBar,
                     pixelsPerBar: pixelsPerBar, scrollX: scrollX, endX: endX)
        
        // Then draw half-bar lines
        for barIndex in stride(from: startBar, to: endBar, by: 1) {
            let barStartBeat = Double(barIndex * timeSignature)
            let halfBarBeat = barStartBeat + Double(timeSignature) / 2.0
            let halfBarX = CGFloat(halfBarBeat * pixelsPerBeat)
            
            // Skip if outside viewport with a small margin
            if halfBarX < scrollX - 1 || halfBarX > scrollX + size.width + 1 {
                continue
            }
            
            // Draw the half-bar line
            var path = Path()
            path.move(to: CGPoint(x: halfBarX, y: 0))
            path.addLine(to: CGPoint(x: halfBarX, y: size.height))
            
            context.stroke(
                path,
                with: .color(themeManager.gridLineColor.opacity(0.5)),
                lineWidth: 0.5
            )
        }
    }
    
    // Draw grid lines at quarter bar positions (each beat in 4/4) for zoom levels 1-2
    private func drawQuarterBarLines(context: GraphicsContext, size: CGSize, 
                                    startBar: Int, endBar: Int, pixelsPerBar: Double, pixelsPerBeat: Double,
                                    scrollX: CGFloat, endX: CGFloat) {
        let timeSignature = projectViewModel.timeSignatureBeats
        
        // First draw bar lines and half-bar lines
        drawHalfBarLines(context: context, size: size, startBar: startBar, endBar: endBar,
                        pixelsPerBar: pixelsPerBar, pixelsPerBeat: pixelsPerBeat, 
                        scrollX: scrollX, endX: endX)
        
        // Then draw quarter-bar lines (typically beats 2 and 4 in 4/4 time)
        for barIndex in stride(from: startBar, to: endBar, by: 1) {
            let barStartBeat = Double(barIndex * timeSignature)
            
            // Draw lines at each beat that isn't a bar start or half-bar
            for beatOffset in 0..<timeSignature {
                // Skip the first beat (bar start) and the half-bar marker (typically beat 3 in 4/4)
                if beatOffset == 0 || beatOffset == timeSignature / 2 {
                    continue
                }
                
                let beatPosition = barStartBeat + Double(beatOffset)
                let beatX = CGFloat(beatPosition * pixelsPerBeat)
                
                // Skip if outside viewport with a small margin
                if beatX < scrollX - 1 || beatX > scrollX + size.width + 1 {
                    continue
                }
                
                // Draw the beat line
                var path = Path()
                path.move(to: CGPoint(x: beatX, y: 0))
                path.addLine(to: CGPoint(x: beatX, y: size.height))
                
                context.stroke(
                    path,
                    with: .color(themeManager.gridLineColor.opacity(0.4)),
                    lineWidth: 0.5
                )
            }
        }
    }
    
    // Draw grid lines at eighth bar positions for zoom level 0
    private func drawEighthBarLines(context: GraphicsContext, size: CGSize, 
                                   startBar: Int, endBar: Int, pixelsPerBar: Double, pixelsPerBeat: Double,
                                   scrollX: CGFloat, endX: CGFloat) {
        let timeSignature = projectViewModel.timeSignatureBeats
        
        // First draw quarter-bar lines (including bar and half-bar lines)
        drawQuarterBarLines(context: context, size: size, startBar: startBar, endBar: endBar,
                           pixelsPerBar: pixelsPerBar, pixelsPerBeat: pixelsPerBeat, 
                           scrollX: scrollX, endX: endX)
        
        // Then draw eighth-note lines between quarter positions
        for barIndex in stride(from: startBar, to: endBar, by: 1) {
            let barStartBeat = Double(barIndex * timeSignature)
            
            // For each beat in the bar
            for beatOffset in 0..<timeSignature {
                let beatPosition = barStartBeat + Double(beatOffset)
                
                // Draw eighth note lines - these are at +0.5 from each beat
                let eighthPosition = beatPosition + 0.5
                let eighthX = CGFloat(eighthPosition * pixelsPerBeat)
                
                // Skip if outside viewport with a small margin
                if eighthX < scrollX - 1 || eighthX > scrollX + size.width + 1 {
                    continue
                }
                
                // Draw the eighth-note line
                var path = Path()
                path.move(to: CGPoint(x: eighthX, y: 0))
                path.addLine(to: CGPoint(x: eighthX, y: size.height))
                
                context.stroke(
                    path,
                    with: .color(themeManager.gridLineColor.opacity(0.25)),
                    lineWidth: 0.5
                )
                
                // For zoom level 0, draw sixteenth note lines as well
                if state.gridDivision == .sixteenth {
                    // Draw sixteenth note lines at 0.25 and 0.75 of each beat
                    let sixteenthPositions = [beatPosition + 0.25, beatPosition + 0.75]
                    
                    for sixteenthPosition in sixteenthPositions {
                        let sixteenthX = CGFloat(sixteenthPosition * pixelsPerBeat)
                        
                        // Skip if outside viewport with a small margin
                        if sixteenthX < scrollX - 1 || sixteenthX > scrollX + size.width + 1 {
                            continue
                        }
                        
                        // Draw the sixteenth-note line
                        var sixteenthPath = Path()
                        sixteenthPath.move(to: CGPoint(x: sixteenthX, y: 0))
                        sixteenthPath.addLine(to: CGPoint(x: sixteenthX, y: size.height))
                        
                        context.stroke(
                            sixteenthPath,
                            with: .color(themeManager.gridLineColor.opacity(0.15)),
                            lineWidth: 0.5
                        )
                    }
                }
            }
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