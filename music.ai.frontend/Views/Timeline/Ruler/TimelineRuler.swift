import SwiftUI

// Add a computed property extension for ProjectViewModel to handle durationInBeats
extension ProjectViewModel {
    // Fallback implementation for durationInBeats
    var durationInBeats: Double {
        // Calculate based on existing tracks or return a default minimum value
        let totalBeats = tracks.flatMap { track -> [Double] in
            let midiEndBeats = track.midiClips.map { $0.startBeat + $0.duration }
            let audioEndBeats = track.audioClips.map { $0.startBeat + $0.duration }
            return midiEndBeats + audioEndBeats
        }.max() ?? 0.0
        
        // Provide a minimum of 16 bars (assuming 4/4 time signature)
        return max(totalBeats, Double(timeSignatureBeats * 16))
    }
}

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
    
    // Performance optimization constants
    private let viewportMargin: CGFloat = 20 // Extra margin around viewport to prevent pop-in
    private let maxSubdivisionElements = 300 // Maximum subdivision elements to draw
    
    // State to track last render position for scroll optimization
    @State private var lastRenderScrollX: CGFloat = 0
    @State private var scrollRenderThreshold: CGFloat = 10 // Minimum scroll distance to trigger re-render
    
    // Add a state variable to track the start of the drag
    @State private var dragStartZoomLevel: Int? = nil
    
    // Constants for ruler appearance
    private let barNumberHeight: CGFloat = 20
    private let beatTickHeight: CGFloat = 14
    private let eighthTickHeight: CGFloat = 8
    private let sixteenthTickHeight: CGFloat = 5
    
    // Color definitions to fix 'Cannot find X in scope' errors
    private var barLineColor: Color { themeManager.gridLineColor }
    private var beatLineColor: Color { themeManager.secondaryGridColor }
    private var eighthLineColor: Color { themeManager.tertiaryGridColor }
    private var sixteenthLineColor: Color { themeManager.tertiaryGridColor.opacity(0.5) }
    private var barNumberColor: Color { themeManager.primaryTextColor }
    
    var body: some View {
        Canvas { context, size in
            // Calculate grid dimensions
            let pixelsPerBeat = state.effectivePixelsPerBeat
            let beatsPerBar = Double(projectViewModel.timeSignatureBeats)
            let pixelsPerBar = pixelsPerBeat * beatsPerBar
            
            // Calculate visible range based on scroll offset with margin
            let scrollX = state.scrollOffset.x
            let startX = max(0, scrollX - viewportMargin)
            let endX = min(width, startX + size.width + viewportMargin * 2)
            
            // Calculate the visible bar range
            let startBar = max(0, Int(floor(startX / CGFloat(pixelsPerBar))))
            
            // Calculate the maximum bar index based on content width
            let maxBarIndex = Int(ceil(width / CGFloat(pixelsPerBar)))
            let endBar = min(maxBarIndex, Int(ceil(endX / CGFloat(pixelsPerBar))) + 1)
            
            // Calculate the visible width in bars
            let visibleBarWidth = endBar - startBar
            
            // Draw ruler background for improved visibility
            let backgroundRect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
            context.fill(Path(backgroundRect), with: .color(themeManager.rulerBackgroundColor))
            
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
                drawQuarterBarRuler(context: context, size: size)
            }
            
            // Draw the playhead position indicator
            if projectViewModel.isPlaying || true { // Always draw the playhead
                let playheadX = CGFloat(projectViewModel.currentBeat * pixelsPerBeat)
                
                // Only draw if visible in the viewport
                if playheadX >= scrollX - viewportMargin && playheadX <= scrollX + size.width + viewportMargin {
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
            
            // Don't modify state during rendering - this will be handled in the shouldTriggerRedraw method
            // lastRenderScrollX = scrollX
        }
        .frame(height: height)
        .background(themeManager.rulerBackgroundColor)
        .drawingGroup(opaque: false) // Use Metal acceleration for better performance
        // Replace the direct shouldTriggerRedraw with a more reliable approach
        // that won't cause "Modifying state during view update" errors
        .id("ruler-zoom-\(state.zoomLevel)-scrolling-\(state.isScrolling ? "yes" : "no")")
        // We'll use onChange to safely update our tracking state
        .onChange(of: state.scrollOffset) { _, newValue in
            // Safely update lastRenderScrollX using async to avoid "modifying state during view update" errors
            DispatchQueue.main.async {
                self.lastRenderScrollX = newValue.x
            }
        }
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
    
    // Determine if a redraw should be triggered based on performance criteria
    private func shouldTriggerRedraw() -> String {
        // Safely access state properties without modifying them
        let currentZoomLevel = state.zoomLevel
        let isCurrentlyScrolling = state.isScrolling
        let currentScrollX = state.scrollOffset.x
        let currentScrollingSpeed = state.scrollingSpeed
        
        // Always redraw on zoom level changes
        let zoomIdentifier = "zoom-\(currentZoomLevel)"
        
        // If we're scrolling very fast, limit redraw frequency
        if isCurrentlyScrolling {
            let distanceMoved = abs(currentScrollX - lastRenderScrollX)
            
            // Higher scroll speeds means we require more distance before redrawing
            let adaptiveThreshold = min(
                max(10, currentScrollingSpeed / 5), // Scale threshold with speed
                50 // Maximum threshold cap
            )
            
            // Only trigger redraw if we've moved sufficiently or zoom changed
            if distanceMoved > adaptiveThreshold {
                // Update the last rendered scroll position in an async context to avoid state modification during view update
                DispatchQueue.main.async {
                    self.lastRenderScrollX = currentScrollX
                }
                // Return a unique identifier
                return "\(zoomIdentifier)-\(UUID().uuidString)"
            }
        }
        
        // Always provide a unique id when not scrolling to ensure proper renders
        if !isCurrentlyScrolling {
            // Update the last rendered scroll position in an async context
            DispatchQueue.main.async {
                self.lastRenderScrollX = currentScrollX
            }
            return "\(zoomIdentifier)-\(UUID().uuidString)"
        }
        
        // Default identifier that changes with zoom level but not constantly during scrolling
        return zoomIdentifier
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
                
                // Always show bar 1, and then every 2 bars as defined by rulerNumberInterval
                // This ensures bar numbers are displayed correctly at zoom level 5
                if barIndex == 0 || barIndex % state.rulerNumberInterval == 0 {
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
                // For zoom level 1, draw dots at quarter AND eighth bar positions (beats and 8th notes)
                drawBarSubdivisionDots(context: context, size: size, barStartBeat: barStartBeat, 
                                      pixelsPerBeat: pixelsPerBeat, timeSignature: timeSignature,
                                      scrollX: scrollX, endX: endX, divisionCount: 4)
                
                // Additionally add eighth note subdivisions (the "and" of each beat)
                drawEighthNoteSubdivisions(context: context, size: size, barStartBeat: barStartBeat,
                                          pixelsPerBeat: pixelsPerBeat, timeSignature: timeSignature,
                                          scrollX: scrollX, endX: endX)
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
            
            // For zoom level 0, also draw quarter and eighth note markers
            if state.zoomLevel == 0 {
                // First, draw lines at eighth note positions (1.2.5, 1.4.5, etc.)
                drawEighthNoteTicks(context: context, size: size, barStartBeat: barStartBeat,
                                   pixelsPerBeat: pixelsPerBeat, timeSignature: timeSignature,
                                   scrollX: scrollX, endX: endX)
                
                // Next, draw dots at sixteenth note positions (1.2.25, 1.2.75, etc.)
                drawSixteenthNoteDots(context: context, size: size, barStartBeat: barStartBeat,
                                     pixelsPerBeat: pixelsPerBeat, timeSignature: timeSignature,
                                     scrollX: scrollX, endX: endX)
                
                // Also draw dots at quarter positions for consistency
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
    private func drawQuarterBarRuler(context: GraphicsContext, size: CGSize) {
        let scrollX = state.scrollOffset.x
        let projectDuration = Double(projectViewModel.durationInBeats)
        let viewportWidth = size.width
        
        // Cache state values locally to avoid accessing published properties during rendering
        let currentZoomLevel = state.zoomLevel
        let isCurrentlyScrolling = state.isScrolling
        let currentScrollingSpeed = state.scrollingSpeed
        let pixelsPerBeat = state.pixelsPerBeat
        
        // Calculate the visible range - with margin for smooth scrolling
        let startX = max(0, scrollX - viewportMargin)
        let endX = min(projectDuration * pixelsPerBeat, scrollX + viewportWidth + viewportMargin)
        
        // Adaptive stepping based on zoom level and scrolling speed
        let (barSkipFactor, eighthSkipFactor, sixteenthSkipFactor) = getAdaptiveStepFactors(
            zoomLevel: currentZoomLevel,
            isScrolling: isCurrentlyScrolling,
            scrollingSpeed: currentScrollingSpeed
        )
        
        // Draw with combined paths for efficiency
        drawBarsAndNumbers(
            context: context, 
            size: size, 
            startX: startX, 
            endX: endX, 
            scrollX: scrollX, 
            viewportWidth: viewportWidth,
            pixelsPerBeat: pixelsPerBeat,
            zoomLevel: currentZoomLevel,
            skipFactor: barSkipFactor
        )
        
        // Draw beats (quarter notes)
        drawBeats(
            context: context, 
            size: size, 
            startX: startX, 
            endX: endX, 
            scrollX: scrollX, 
            viewportWidth: viewportWidth,
            pixelsPerBeat: pixelsPerBeat
        )
        
        // Draw eighth notes if we're at an appropriate zoom level
        if currentZoomLevel <= 1 || (currentZoomLevel >= 3 && eighthSkipFactor < 2) {
            drawEighthNotes(
                context: context, 
                size: size, 
                startX: startX, 
                endX: endX, 
                scrollX: scrollX, 
                viewportWidth: viewportWidth,
                pixelsPerBeat: pixelsPerBeat,
                skipFactor: eighthSkipFactor
            )
        }
        
        // Draw sixteenth notes at high zoom levels and for zoom level 0
        if currentZoomLevel == 0 || (currentZoomLevel >= 4 && sixteenthSkipFactor < 2) {
            drawSixteenthNotes(
                context: context, 
                size: size, 
                startX: startX, 
                endX: endX, 
                scrollX: scrollX, 
                viewportWidth: viewportWidth,
                pixelsPerBeat: pixelsPerBeat,
                skipFactor: sixteenthSkipFactor
            )
        }
    }
    
    // Helper function to determine rendering detail based on zoom and scrolling
    private func getAdaptiveStepFactors(zoomLevel: Int, isScrolling: Bool, scrollingSpeed: CGFloat) -> (Int, Int, Int) {
        // Default: show everything
        var barSkipFactor = 0
        var eighthSkipFactor = 0
        var sixteenthSkipFactor = 0
        
        // Adjust based on scrolling speed
        if isScrolling {
            if scrollingSpeed > 2000 {
                // Very fast scrolling - minimal detail
                barSkipFactor = 0  // Still show all bars
                eighthSkipFactor = 2  // Skip eighth notes
                sixteenthSkipFactor = 2  // Skip sixteenth notes
            } else if scrollingSpeed > 1000 {
                // Fast scrolling - reduced detail
                barSkipFactor = 0  // Show all bars
                eighthSkipFactor = 1  // Show some eighth notes
                sixteenthSkipFactor = 2  // Skip sixteenth notes
            } else if scrollingSpeed > 500 {
                // Medium speed - moderate detail
                barSkipFactor = 0  // Show all bars
                eighthSkipFactor = 0  // Show all eighth notes
                sixteenthSkipFactor = 1  // Show some sixteenth notes
            }
        }
        
        // Further adjust based on zoom level - modified to allow eighth notes at zoom level 1
        if zoomLevel > 1 && zoomLevel < 3 {
            eighthSkipFactor = max(eighthSkipFactor, 1)
            sixteenthSkipFactor = 2
        }
        
        // Modified to only prevent sixteenth notes at specific levels
        if zoomLevel > 0 && zoomLevel < 4 {
            sixteenthSkipFactor = 2
        }
        
        return (barSkipFactor, eighthSkipFactor, sixteenthSkipFactor)
    }
    
    // Draw bars and bar numbers
    private func drawBarsAndNumbers(context: GraphicsContext, size: CGSize, startX: CGFloat, endX: CGFloat, scrollX: CGFloat, viewportWidth: CGFloat, pixelsPerBeat: CGFloat, zoomLevel: Int, skipFactor: Int) {
        // Create a path for the bars
        let barPath = Path { path in
            var barNumber = Int(startX / (4 * pixelsPerBeat))
            
            while CGFloat(barNumber * 4) * pixelsPerBeat <= endX {
                let x = CGFloat(barNumber * 4) * pixelsPerBeat - scrollX
                
                if x >= -1 && x <= viewportWidth + 1 {
                    // Draw the bar line
                    path.move(to: CGPoint(x: x, y: barNumberHeight))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    
                    // Draw bar numbers (only for visible bars)
                    if x >= 0 && x <= viewportWidth && shouldShowBarNumber(barNumber: barNumber, zoomLevel: zoomLevel) {
                        // Draw text in context instead of in path
                        let text = Text("\(barNumber + 1)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(barNumberColor)
                        
                        // Position the text centered above the bar
                        context.draw(text, at: CGPoint(x: x, y: 1))
                    }
                }
                
                barNumber += 1
            }
        }
        
        // Draw the bar lines
        context.stroke(barPath, with: .color(barLineColor), lineWidth: 1)
    }
    
    // Helper function to determine if a bar number should be displayed based on zoom level
    private func shouldShowBarNumber(barNumber: Int, zoomLevel: Int) -> Bool {
        // Always show the first bar
        if barNumber == 0 {
            return true
        }
        
        // For zoom levels 0-3, show numbers for every bar
        if zoomLevel <= 3 {
            return true
        }
        
        // For zoom level 4-5, show odd-numbered bars only
        if zoomLevel == 4 || zoomLevel == 5 {
            return (barNumber + 1) % 2 == 1
        }
        
        // For zoom level 6, show every 4th bar
        if zoomLevel == 6 {
            return (barNumber + 1) % 4 == 0
        }
        
        return false
    }
    
    // Draw beat lines (quarter notes)
    private func drawBeats(context: GraphicsContext, size: CGSize, startX: CGFloat, endX: CGFloat, scrollX: CGFloat, viewportWidth: CGFloat, pixelsPerBeat: CGFloat) {
        let beatPath = Path { path in
            var beat = Int(startX / pixelsPerBeat)
            
            while CGFloat(beat) * pixelsPerBeat <= endX {
                // Only draw beats that aren't bar lines
                if beat % 4 != 0 {
                    let x = CGFloat(beat) * pixelsPerBeat - scrollX
                    
                    if x >= -1 && x <= viewportWidth + 1 {
                        path.move(to: CGPoint(x: x, y: beatTickHeight))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    }
                }
                
                beat += 1
            }
        }
        
        context.stroke(beatPath, with: .color(beatLineColor), lineWidth: 0.5)
    }
    
    // Draw eighth notes
    private func drawEighthNotes(context: GraphicsContext, size: CGSize, startX: CGFloat, endX: CGFloat, scrollX: CGFloat, viewportWidth: CGFloat, pixelsPerBeat: CGFloat, skipFactor: Int) {
        let eighthPath = Path { path in
            var eighth = Int(startX / (pixelsPerBeat / 2))
            
            while CGFloat(eighth) * (pixelsPerBeat / 2) <= endX {
                let isEven = eighth % 2 == 0
                
                // Special handling for zoom level 1 - ensure all eighth notes appear
                let shouldDrawForZoom1 = state.zoomLevel == 1 && !isEven
                
                // Skip even eighth notes when using skip factor (except for zoom level 1)
                if shouldDrawForZoom1 || (skipFactor == 0 || !isEven) {
                    // Only draw if it's not a beat line (every 2nd eighth)
                    if !isEven {
                        let x = CGFloat(eighth) * (pixelsPerBeat / 2) - scrollX
                        
                        if x >= -1 && x <= viewportWidth + 1 {
                            // Use a different tick height for zoom level 1
                            let tickHeight = state.zoomLevel == 1 ? 
                                eighthTickHeight + 1 : eighthTickHeight
                                
                            path.move(to: CGPoint(x: x, y: tickHeight))
                            path.addLine(to: CGPoint(x: x, y: size.height))
                        }
                    }
                }
                
                eighth += 1
            }
        }
        
        // Use a more appropriate color and line width for eighth notes at zoom level 1
        let lineWidth: CGFloat = state.zoomLevel == 1 ? 0.5 : 0.4
        let lineColor = state.zoomLevel == 1 ? 
            eighthLineColor.opacity(0.9) : eighthLineColor
        
        context.stroke(eighthPath, with: .color(lineColor), lineWidth: lineWidth)
    }
    
    // Draw sixteenth notes
    private func drawSixteenthNotes(context: GraphicsContext, size: CGSize, startX: CGFloat, endX: CGFloat, scrollX: CGFloat, viewportWidth: CGFloat, pixelsPerBeat: CGFloat, skipFactor: Int) {
        let sixteenthPath = Path { path in
            var sixteenth = Int(startX / (pixelsPerBeat / 4))
            
            while CGFloat(sixteenth) * (pixelsPerBeat / 4) <= endX {
                let isFourthSixteenth = sixteenth % 4 == 0
                let isSecondSixteenth = sixteenth % 2 == 0
                
                // Logic for which sixteenth notes to draw based on skip factor and zoom level
                var shouldDraw = false
                
                if state.zoomLevel == 0 {
                    // For zoom level 0, we want to show all sixteenth notes
                    // But avoid ones that coincide with quarter or eighth notes
                    shouldDraw = !isSecondSixteenth && !isFourthSixteenth
                } else if skipFactor == 0 {
                    // Draw all sixteenth notes that aren't on eighth or quarter lines
                    shouldDraw = !isSecondSixteenth
                } else if skipFactor == 1 {
                    // Draw only odd sixteenth notes after odd eighths (reduced density)
                    shouldDraw = !isSecondSixteenth && !isFourthSixteenth && (sixteenth % 4 == 1)
                }
                
                if shouldDraw {
                    let x = CGFloat(sixteenth) * (pixelsPerBeat / 4) - scrollX
                    
                    if x >= -1 && x <= viewportWidth + 1 {
                        path.move(to: CGPoint(x: x, y: sixteenthTickHeight))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    }
                }
                
                sixteenth += 1
            }
        }
        
        // Use a more appropriate color and line width for sixteenth notes based on zoom level
        let lineWidth: CGFloat = state.zoomLevel == 0 ? 0.4 : 0.3
        let lineColor = state.zoomLevel == 0 ? 
            sixteenthLineColor.opacity(0.7) : sixteenthLineColor
        
        context.stroke(sixteenthPath, with: .color(lineColor), lineWidth: lineWidth)
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
    
    // Helper method to draw eighth note subdivisions (the "and" of each beat)
    private func drawEighthNoteSubdivisions(context: GraphicsContext, size: CGSize, barStartBeat: Double,
                                           pixelsPerBeat: Double, timeSignature: Int, scrollX: CGFloat, endX: CGFloat) {
        // For each beat in the bar
        for beatIndex in 0..<timeSignature {
            // Calculate the position of the 8th note (the "and" of the beat)
            let eighthBeat = barStartBeat + Double(beatIndex) + 0.5 // Add 0.5 for the eighth note position
            let eighthX = CGFloat(eighthBeat * pixelsPerBeat)
            
            // Skip if outside the viewport
            if eighthX < scrollX || eighthX > scrollX + size.width {
                continue
            }
            
            // Draw a dot at this eighth note position
            let dotPath = Path(ellipseIn: CGRect(
                x: eighthX - dotRadius,
                y: size.height - eighthBarTickHeight,
                width: dotRadius * 2,
                height: dotRadius * 2
            ))
            
            context.fill(
                dotPath,
                with: .color(themeManager.secondaryTextColor.opacity(0.7))
            )
        }
    }
    
    // Helper method to draw eighth note tick lines for zoom level 0
    private func drawEighthNoteTicks(context: GraphicsContext, size: CGSize, barStartBeat: Double,
                                    pixelsPerBeat: Double, timeSignature: Int, scrollX: CGFloat, endX: CGFloat) {
        // For each beat in the bar
        for beatIndex in 0..<timeSignature {
            // Calculate the eighth note position (halfway between beats)
            let eighthBeat = barStartBeat + Double(beatIndex) + 0.5 // Add 0.5 for the eighth note position
            let eighthX = CGFloat(eighthBeat * pixelsPerBeat)
            
            // Skip if outside the viewport
            if eighthX < scrollX || eighthX > scrollX + size.width {
                continue
            }
            
            // Draw a tick line at this eighth note position
            var eighthPath = Path()
            eighthPath.move(to: CGPoint(x: eighthX, y: size.height - eighthBarTickHeight))
            eighthPath.addLine(to: CGPoint(x: eighthX, y: size.height))
            
            context.stroke(
                eighthPath,
                with: .color(themeManager.tertiaryGridColor),
                lineWidth: 0.5
            )
        }
    }
    
    // Helper method to draw sixteenth note dots for zoom level 0
    private func drawSixteenthNoteDots(context: GraphicsContext, size: CGSize, barStartBeat: Double,
                                      pixelsPerBeat: Double, timeSignature: Int, scrollX: CGFloat, endX: CGFloat) {
        // For each beat in the bar
        for beatIndex in 0..<timeSignature {
            // Calculate the base beat position
            let baseBeat = barStartBeat + Double(beatIndex)
            
            // Draw dots at 16th note positions (x.x.25 and x.x.75)
            let sixteenthPositions: [Double] = [0.25, 0.75] // 16th note offsets within a beat
            
            for sixteenthOffset in sixteenthPositions {
                let sixteenthBeat = baseBeat + sixteenthOffset
                let sixteenthX = CGFloat(sixteenthBeat * pixelsPerBeat)
                
                // Skip if outside the viewport
                if sixteenthX < scrollX || sixteenthX > scrollX + size.width {
                    continue
                }
                
                // Draw a smaller dot at this sixteenth note position
                let sixteenthDotRadius = dotRadius * 0.8 // Slightly smaller than standard dots
                let dotPath = Path(ellipseIn: CGRect(
                    x: sixteenthX - sixteenthDotRadius,
                    y: size.height - eighthBarTickHeight,
                    width: sixteenthDotRadius * 2,
                    height: sixteenthDotRadius * 2
                ))
                
                context.fill(
                    dotPath,
                    with: .color(themeManager.tertiaryGridColor.opacity(0.6))
                )
            }
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
