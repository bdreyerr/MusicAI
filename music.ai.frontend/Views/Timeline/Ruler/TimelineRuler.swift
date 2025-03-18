import SwiftUI

/// Ruler component that displays bar and beat markers at the top of the timeline
struct TimelineRuler: View {
    @ObservedObject var state: TimelineStateViewModel
    @ObservedObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var themeManager: ThemeManager
    let width: CGFloat
    let height: CGFloat
    
    // Constants for ruler styling
    private let barTickHeight: CGFloat = 6 // Bar ticks
    private let halfBarTickHeight: CGFloat = 5 // Half-bar ticks
    private let quarterBarTickHeight: CGFloat = 4 // Quarter-bar ticks
    private let eighthBarTickHeight: CGFloat = 3 // Eighth-bar ticks
    private let barTickWidth: CGFloat = 1.0 // Width of bar ticks
    private let horizontalMarkerWidth: CGFloat = 1 // Width of horizontal marker at top of bar lines
    private let dotRadius: CGFloat = 1.0 // Radius for standard dots
    private let halfBarDotRadius: CGFloat = 1.2 // Radius for half-bar dots
    private let barDotRadius: CGFloat = 1.5 // Radius for bar dots
    
    // Add a state variable to track the start of the drag
    @State private var dragStartZoomLevel: Int? = nil
    
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
            
            // Draw ruler marks based on zoom level
            switch state.rulerDivision {
            case .fourBar:
                // Show lines every 4 bars, dots every 2 bars
                drawFourBarRuler(context: context, 
                                  size: size, 
                                  startBar: startBar, 
                                  endBar: endBar, 
                                  pixelsPerBar: pixelsPerBar, 
                                  scrollX: scrollX, 
                                  endX: endX)
            case .twoBar:
                // Show lines every 2 bars, dots every 1 bar
                drawTwoBarRuler(context: context, 
                                 size: size, 
                                 startBar: startBar, 
                                 endBar: endBar, 
                                 pixelsPerBar: pixelsPerBar, 
                                 scrollX: scrollX, 
                                 endX: endX)
            case .bar:
                // Show lines every 1 bar, dots at intervals based on zoom level
                drawOneBarRuler(context: context, 
                                 size: size, 
                                 startBar: startBar, 
                                 endBar: endBar, 
                                 pixelsPerBar: pixelsPerBar, 
                                 pixelsPerBeat: pixelsPerBeat,
                                 scrollX: scrollX, 
                                 endX: endX)
            case .half:
                // Show lines every half bar (beats 1 and 3 in 4/4)
                drawHalfBarRuler(context: context, 
                                  size: size, 
                                  startBar: startBar, 
                                  endBar: endBar, 
                                  pixelsPerBar: pixelsPerBar, 
                                  pixelsPerBeat: pixelsPerBeat,
                                  scrollX: scrollX, 
                                  endX: endX)
            case .quarter, .eighth, .sixteenth:
                // Show lines every quarter bar (every beat in 4/4)
                drawQuarterBarRuler(context: context, 
                                     size: size, 
                                     startBar: startBar, 
                                     endBar: endBar, 
                                     pixelsPerBar: pixelsPerBar, 
                                     pixelsPerBeat: pixelsPerBeat,
                                     scrollX: scrollX, 
                                     endX: endX)
            }
            
            // Draw the playhead position indicator
            if projectViewModel.isPlaying || true { // Always draw the playhead
                let playheadX = CGFloat(projectViewModel.currentBeat * pixelsPerBeat)
                
                // Only draw if visible in the viewport
                if playheadX >= scrollX && playheadX <= scrollX + size.width {
                    var playheadPath = Path()
                    playheadPath.move(to: CGPoint(x: playheadX, y: 0))
                    playheadPath.addLine(to: CGPoint(x: playheadX, y: size.height))
                    
                    context.stroke(
                        playheadPath,
                        with: .color(.blue),
                        lineWidth: 1.0
                    )
                }
            }
        }
        .frame(height: height)
        .background(themeManager.rulerBackgroundColor)
        .drawingGroup(opaque: false) // Use Metal acceleration for better performance
        // Add a tap gesture to clear the selection and move the playhead
        .contentShape(Rectangle())
        .onTapGesture { location in
            // Calculate the beat position from the tap location
            let rawBeatPosition = location.x / CGFloat(state.effectivePixelsPerBeat)
            
            // Snap to the nearest grid marker
            let snappedBeatPosition = snapToNearestGridMarker(rawBeatPosition)
            
            // Move the playhead
            projectViewModel.seekToBeat(snappedBeatPosition)
            
            // Clear any selection
            state.clearSelection()
        }
        // Add a drag gesture to zoom in/out
        .gesture(
            DragGesture(minimumDistance: 5)
                .onChanged { value in
                    // Only handle vertical drags (ignore horizontal movement)
                    if abs(value.translation.height) > abs(value.translation.width) {
                        // Save the starting zoom level when the drag begins
                        if dragStartZoomLevel == nil {
                            dragStartZoomLevel = state.zoomLevel
                        }
                        
                        // Calculate zoom adjustment based on drag distance
                        // Drag up to zoom OUT, drag down to zoom IN
                        let dragDistance = value.translation.height
                        
                        // Require much more drag distance for zoom transitions
                        // Each zoom level change requires 120 pixels of drag
                        let zoomThreshold: CGFloat = 120
                        
                        // Calculate the desired zoom level based on the starting point and drag distance
                        let desiredChange = Int(dragDistance / zoomThreshold)
                        
                        // Calculate the target zoom level based on the starting level and drag
                        let targetZoomLevel = max(0, min(6, dragStartZoomLevel! - desiredChange))
                        
                        // Only update if the target level is different
                        if targetZoomLevel != state.zoomLevel {
                            state.zoomLevel = targetZoomLevel
                        }
                    }
                }
                .onEnded { _ in
                    // Reset the starting zoom level when the drag ends
                    dragStartZoomLevel = nil
                }
        )
        // Set cursor to indicate zoom functionality with vertical dragging
        .onHover { isHovering in
            if isHovering {
                // Use the pointing hand cursor to indicate interactive zoom area
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
    
    // MARK: - Ruler Drawing Methods
    
    // Draw ruler with lines every 4 bars, dots at 2-bar intervals
    private func drawFourBarRuler(context: GraphicsContext, size: CGSize, startBar: Int, endBar: Int, 
                                  pixelsPerBar: Double, scrollX: CGFloat, endX: CGFloat) {
        let timeSignature = projectViewModel.timeSignatureBeats
        
        // Calculate the actual range of bars to show, aligned to 4-bar boundaries
        let adjustedStartBar = (startBar / 4) * 4
        
        for barIndex in stride(from: adjustedStartBar, to: endBar, by: 1) {
            let xPosition = CGFloat(Double(barIndex) * pixelsPerBar)
            
            // Skip if outside the viewport
            if xPosition + CGFloat(pixelsPerBar) < scrollX || xPosition > scrollX + size.width {
                continue
            }
            
            // Determine if this is a 4-bar boundary (main line)
            let isFourBarBoundary = barIndex % 4 == 0
            
            // Determine if this is a 2-bar boundary (dot)
            let isTwoBarBoundary = barIndex % 2 == 0 && !isFourBarBoundary
            
            if isFourBarBoundary {
                // Draw main tick line at 4-bar intervals
                var path = Path()
                path.move(to: CGPoint(x: xPosition, y: size.height - barTickHeight))
                path.addLine(to: CGPoint(x: xPosition, y: size.height))
                
                context.stroke(
                    path,
                    with: .color(themeManager.primaryTextColor),
                    lineWidth: barTickWidth
                )
                
                // Draw bar number at 4-bar intervals - always show bar 1 and every 4th bar
                // We enforce this directly here to ensure numbers are visible at zoom level 6
                if barIndex == 0 || barIndex % 4 == 0 {
                    let text = Text("\(barIndex + 1)")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(themeManager.primaryTextColor)
                    
                    context.draw(text, at: CGPoint(x: xPosition + 4, y: 4))
                }
            } else if isTwoBarBoundary {
                // Draw a dot at 2-bar intervals
                let dotPath = Path(ellipseIn: CGRect(
                    x: xPosition - barDotRadius,
                    y: size.height - barTickHeight,
                    width: barDotRadius * 2,
                    height: barDotRadius * 2
                ))
                
                context.fill(
                    dotPath,
                    with: .color(themeManager.secondaryTextColor)
                )
            }
        }
    }
    
    // Draw ruler with lines every 2 bars, dots at 1-bar intervals
    private func drawTwoBarRuler(context: GraphicsContext, size: CGSize, startBar: Int, endBar: Int, 
                                 pixelsPerBar: Double, scrollX: CGFloat, endX: CGFloat) {
        let timeSignature = projectViewModel.timeSignatureBeats
        
        // Calculate the actual range of bars to show, aligned to 2-bar boundaries
        let adjustedStartBar = (startBar / 2) * 2
        
        for barIndex in stride(from: adjustedStartBar, to: endBar, by: 1) {
            let xPosition = CGFloat(Double(barIndex) * pixelsPerBar)
            
            // Skip if outside the viewport
            if xPosition + CGFloat(pixelsPerBar) < scrollX || xPosition > scrollX + size.width {
                continue
            }
            
            // Determine if this is a 2-bar boundary (main line)
            let isTwoBarBoundary = barIndex % 2 == 0
            
            // Determine if this is a 1-bar position (dot)
            let isOneBarPosition = !isTwoBarBoundary
            
            if isTwoBarBoundary {
                // Draw main tick line at 2-bar intervals
                var path = Path()
                path.move(to: CGPoint(x: xPosition, y: size.height - barTickHeight))
                path.addLine(to: CGPoint(x: xPosition, y: size.height))
                
                context.stroke(
                    path,
                    with: .color(themeManager.primaryTextColor),
                    lineWidth: barTickWidth
                )
                
                // Draw bar number if at a 2-bar interval
                if state.shouldShowBarNumber(for: barIndex) {
                    let text = Text("\(barIndex + 1)")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(themeManager.primaryTextColor)
                    
                    context.draw(text, at: CGPoint(x: xPosition + 4, y: 4))
                }
            } else if isOneBarPosition {
                // Draw a dot at 1-bar intervals
                let dotPath = Path(ellipseIn: CGRect(
                    x: xPosition - barDotRadius,
                    y: size.height - barTickHeight,
                    width: barDotRadius * 2,
                    height: barDotRadius * 2
                ))
                
                context.fill(
                    dotPath,
                    with: .color(themeManager.secondaryTextColor)
                )
            }
        }
    }
    
    // Draw ruler with lines every 1 bar, dots at half-bar or quarter-bar intervals
    private func drawOneBarRuler(context: GraphicsContext, size: CGSize, startBar: Int, endBar: Int, 
                                 pixelsPerBar: Double, pixelsPerBeat: Double, scrollX: CGFloat, endX: CGFloat) {
        let timeSignature = projectViewModel.timeSignatureBeats
        
        for barIndex in stride(from: startBar, to: endBar, by: 1) {
            let barStartBeat = Double(barIndex * timeSignature)
            let xPosition = CGFloat(barStartBeat * pixelsPerBeat)
            
            // Skip if outside the viewport
            if xPosition + CGFloat(pixelsPerBar) < scrollX || xPosition > scrollX + size.width {
                continue
            }
            
            // Draw main tick line at each bar
            var path = Path()
            path.move(to: CGPoint(x: xPosition, y: size.height - barTickHeight))
            path.addLine(to: CGPoint(x: xPosition, y: size.height))
            
            context.stroke(
                path,
                with: .color(themeManager.primaryTextColor),
                lineWidth: barTickWidth
            )
            
            // Draw bar number
            if state.shouldShowBarNumber(for: barIndex) {
                let text = Text("\(barIndex + 1)")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(themeManager.primaryTextColor)
                
                context.draw(text, at: CGPoint(x: xPosition + 4, y: 4))
            }
            
            // For zoom levels 1-3, draw dots at intervals within the bar
            // Check the zoom level to determine dot spacing
            if state.zoomLevel == 1 {
                // For zoom level 1, draw dots at quarter bar positions (beats)
                drawBarSubdivisionDots(context: context, size: size, barStartBeat: barStartBeat, 
                                      pixelsPerBeat: pixelsPerBeat, timeSignature: timeSignature,
                                      scrollX: scrollX, endX: endX, divisionCount: 4)
            } else if state.zoomLevel == 2 || state.zoomLevel == 3 {
                // For zoom levels 2-3, draw dots at half bar positions
                drawBarSubdivisionDots(context: context, size: size, barStartBeat: barStartBeat, 
                                      pixelsPerBeat: pixelsPerBeat, timeSignature: timeSignature,
                                      scrollX: scrollX, endX: endX, divisionCount: 2)
            }
        }
    }
    
    // Draw ruler with lines every half bar, dots at quarter-bar intervals
    private func drawHalfBarRuler(context: GraphicsContext, size: CGSize, startBar: Int, endBar: Int, 
                                  pixelsPerBar: Double, pixelsPerBeat: Double, scrollX: CGFloat, endX: CGFloat) {
        let timeSignature = projectViewModel.timeSignatureBeats
        
        for barIndex in stride(from: startBar, to: endBar, by: 1) {
            let barStartBeat = Double(barIndex * timeSignature)
            
            // Draw main tick at the start of each bar
            let barStartX = CGFloat(barStartBeat * pixelsPerBeat)
            
            // Skip if outside the viewport
            if barStartX + CGFloat(pixelsPerBar) < scrollX || barStartX > scrollX + size.width {
                continue
            }
            
            // Draw main bar tick line
            var barPath = Path()
            barPath.move(to: CGPoint(x: barStartX, y: size.height - barTickHeight))
            barPath.addLine(to: CGPoint(x: barStartX, y: size.height))
            
            context.stroke(
                barPath,
                with: .color(themeManager.primaryTextColor),
                lineWidth: barTickWidth
            )
            
            // Draw bar number at bar start
            if state.shouldShowBarNumber(for: barIndex) {
                let text = Text("\(barIndex + 1)")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(themeManager.primaryTextColor)
                
                context.draw(text, at: CGPoint(x: barStartX + 4, y: 4))
            }
            
            // Draw half-bar tick (at beat 3 in 4/4 time)
            let halfBarBeat = barStartBeat + Double(timeSignature) / 2.0
            let halfBarX = CGFloat(halfBarBeat * pixelsPerBeat)
            
            // Check if half-bar position is visible
            if halfBarX >= scrollX && halfBarX <= scrollX + size.width {
                var halfBarPath = Path()
                halfBarPath.move(to: CGPoint(x: halfBarX, y: size.height - halfBarTickHeight))
                halfBarPath.addLine(to: CGPoint(x: halfBarX, y: size.height))
                
                context.stroke(
                    halfBarPath,
                    with: .color(themeManager.primaryTextColor.opacity(0.8)),
                    lineWidth: barTickWidth
                )
            }
            
            // For zoom level 0, also draw quarter-bar dots
            if state.zoomLevel == 0 {
                // Draw dots at 1/4 and 3/4 positions
                for i in 0..<timeSignature {
                    if i == 0 || i == timeSignature / 2 {
                        // Skip main positions (already have lines)
                        continue
                    }
                    
                    let beatPosition = barStartBeat + Double(i)
                    let beatX = CGFloat(beatPosition * pixelsPerBeat)
                    
                    // Check if position is visible
                    if beatX >= scrollX && beatX <= scrollX + size.width {
                        let dotPath = Path(ellipseIn: CGRect(
                            x: beatX - dotRadius,
                            y: size.height - quarterBarTickHeight,
                            width: dotRadius * 2,
                            height: dotRadius * 2
                        ))
                        
                        context.fill(
                            dotPath,
                            with: .color(themeManager.secondaryTextColor)
                        )
                    }
                }
            }
        }
    }
    
    // Draw ruler with lines every quarter bar (every beat in 4/4)
    private func drawQuarterBarRuler(context: GraphicsContext, size: CGSize, startBar: Int, endBar: Int, 
                                     pixelsPerBar: Double, pixelsPerBeat: Double, scrollX: CGFloat, endX: CGFloat) {
        let timeSignature = projectViewModel.timeSignatureBeats
        
        for barIndex in stride(from: startBar, to: endBar, by: 1) {
            let barStartBeat = Double(barIndex * timeSignature)
            
            // Draw lines at each beat
            for beatOffset in 0..<timeSignature {
                let beatPosition = barStartBeat + Double(beatOffset)
                let beatX = CGFloat(beatPosition * pixelsPerBeat)
                
                // Skip if outside the viewport
                if beatX < scrollX || beatX > scrollX + size.width {
                    continue
                }
                
                // Determine if this is the start of a bar
                let isBarStart = beatOffset == 0
                
                // Draw tick line
                var path = Path()
                path.move(to: CGPoint(x: beatX, y: size.height - (isBarStart ? barTickHeight : quarterBarTickHeight)))
                path.addLine(to: CGPoint(x: beatX, y: size.height))
                
                context.stroke(
                    path,
                    with: .color(isBarStart ? themeManager.primaryTextColor : themeManager.primaryTextColor.opacity(0.7)),
                    lineWidth: barTickWidth
                )
                
                // Draw bar numbers at bar start and special beat markings
                if isBarStart {
                    if state.shouldShowBarNumber(for: barIndex) {
                        let text = Text("\(barIndex + 1)")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(themeManager.primaryTextColor)
                        
                        context.draw(text, at: CGPoint(x: beatX + 4, y: 4))
                    }
                } else if state.zoomLevel == 0 {
                    // For zoom level 0, show beat numbers within the bar
                    let text = Text("\(barIndex + 1).\(beatOffset + 1)")
                        .font(.system(size: 8, weight: .light))
                        .foregroundColor(themeManager.secondaryTextColor)
                    
                    context.draw(text, at: CGPoint(x: beatX + 3, y: 5))
                }
                
                // Draw eighth note markers at exact 0.5 positions between beats (for zoom level 0 and 1)
                if state.zoomLevel <= 1 {
                    // Draw exactly at the halfway point (0.5) between beats
                    let eighthPosition = beatPosition + 0.5
                    let eighthX = CGFloat(eighthPosition * pixelsPerBeat)
                    
                    // Check if position is visible
                    if eighthX >= scrollX && eighthX <= scrollX + size.width {
                        if state.zoomLevel == 0 {
                            // For zoom level 0, draw a small tick line
                            var eighthPath = Path()
                            eighthPath.move(to: CGPoint(x: eighthX, y: size.height - eighthBarTickHeight))
                            eighthPath.addLine(to: CGPoint(x: eighthX, y: size.height))
                            
                            context.stroke(
                                eighthPath,
                                with: .color(themeManager.primaryTextColor.opacity(0.5)),
                                lineWidth: 0.5
                            )
                        } else {
                            // For zoom level 1, draw a dot
                            let dotPath = Path(ellipseIn: CGRect(
                                x: eighthX - dotRadius,
                                y: size.height - eighthBarTickHeight,
                                width: dotRadius * 2,
                                height: dotRadius * 2
                            ))
                            
                            context.fill(
                                dotPath,
                                with: .color(themeManager.secondaryTextColor.opacity(0.6))
                            )
                        }
                    }
                    
                    // For zoom level 0, also draw sixteenth note dots at 0.25 and 0.75 positions
                    if state.zoomLevel == 0 {
                        let sixteenthPositions = [beatPosition + 0.25, beatPosition + 0.75]
                        
                        for sixteenthPosition in sixteenthPositions {
                            let sixteenthX = CGFloat(sixteenthPosition * pixelsPerBeat)
                            
                            // Check if position is visible
                            if sixteenthX >= scrollX && sixteenthX <= scrollX + size.width {
                                let dotPath = Path(ellipseIn: CGRect(
                                    x: sixteenthX - dotRadius * 0.8,
                                    y: size.height - eighthBarTickHeight + 1,
                                    width: dotRadius * 1.6,
                                    height: dotRadius * 1.6
                                ))
                                
                                context.fill(
                                    dotPath,
                                    with: .color(themeManager.secondaryTextColor.opacity(0.5))
                                )
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Helper method to draw subdivision dots within a bar
    private func drawBarSubdivisionDots(context: GraphicsContext, size: CGSize, barStartBeat: Double,
                                       pixelsPerBeat: Double, timeSignature: Int, scrollX: CGFloat, endX: CGFloat,
                                       divisionCount: Int) {
        let beatsPerDivision = Double(timeSignature) / Double(divisionCount)
        
        for divIndex in 1..<divisionCount {
            let divBeat = barStartBeat + Double(divIndex) * beatsPerDivision
            let divX = CGFloat(divBeat * pixelsPerBeat)
            
            // Skip if outside the viewport
            if divX < scrollX || divX > scrollX + size.width {
                continue
            }
            
            // Draw a dot at this division
            let dotRadius = divisionCount <= 2 ? halfBarDotRadius : dotRadius
            let dotPath = Path(ellipseIn: CGRect(
                x: divX - dotRadius,
                y: size.height - (divisionCount <= 2 ? halfBarTickHeight : quarterBarTickHeight),
                width: dotRadius * 2,
                height: dotRadius * 2
            ))
            
            context.fill(
                dotPath,
                with: .color(themeManager.secondaryTextColor)
            )
        }
    }
    
    // Snap a beat position to the nearest grid marker based on zoom level
    private func snapToNearestGridMarker(_ rawBeatPosition: Double) -> Double {
        // Determine the smallest visible grid division based on zoom level
        let timeSignature = projectViewModel.timeSignatureBeats
        
        switch state.gridDivision {
        case .sixteenth, .eighth:
            // Snap to eighth notes (0.125 beat)
            return round(rawBeatPosition * 8.0) / 8.0
            
        case .quarter:
            // Snap to quarter notes (0.25 beat)
            return round(rawBeatPosition * 4.0) / 4.0
            
        case .half:
            // For half-bar markers (assuming 4/4 time, this would be beat 2)
            let beatsPerBar = Double(timeSignature)
            
            // Calculate the bar index and position within the bar
            let barIndex = floor(rawBeatPosition / beatsPerBar)
            let positionInBar = rawBeatPosition - (barIndex * beatsPerBar)
            
            // Check if we're closer to the start of the bar, middle of the bar, or end of the bar
            if positionInBar < beatsPerBar / 4.0 {
                // Snap to start of bar
                return barIndex * beatsPerBar
            } else if positionInBar > (beatsPerBar * 3.0) / 4.0 {
                // Snap to start of next bar
                return (barIndex + 1) * beatsPerBar
            } else {
                // Snap to half-bar
                return barIndex * beatsPerBar + beatsPerBar / 2.0
            }
            
        case .bar, .twoBar, .fourBar:
            // When zoomed out, snap to bars
            let beatsPerBar = Double(timeSignature)
            return round(rawBeatPosition / beatsPerBar) * beatsPerBar
        }
    }
}

#Preview {
    TimelineRuler(
        state: TimelineStateViewModel(),
        projectViewModel: ProjectViewModel(),
        width: 800,
        height: 40
    )
    .environmentObject(ThemeManager())
} 
