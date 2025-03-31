import SwiftUI

/// Draws the static content of the timeline ruler (lines and numbers) for the entire project duration.
/// This view is designed to be drawn once and then scrolled horizontally by its parent.
struct RulerStaticContentView: View {
    // Use specific properties instead of the whole state object for clarity
    let zoomLevel: Int
    let effectivePixelsPerBeat: Double
    let timeSignatureBeats: Int
    let totalBars: Int
    let rulerHeight: CGFloat
    
    // Viewport offset - now needed to determine what text to draw
    let viewportScrollOffset: CGPoint
    let viewportWidth: CGFloat
    
    @EnvironmentObject var themeManager: ThemeManager
    
    // Cache for the rendered ruler image to avoid redrawing during scrolling
    @State private var cachedRulerImage: Image? = nil
    @State private var lastCacheParams: CacheParams? = nil
    
    // For debugging
    @State private var debugInfo: String = ""
    
    // Use a computed property instead of a mutable state for text count
    private var textElementCount: Int {
        // Estimate based on visible bars - just for debugging purposes
        let (start, end) = visibleBarRange
        let barsVisible = end - start
        if zoomLevel == 0 {
            // Rough estimate for zoom level 0
            return barsVisible * timeSignatureBeats + 1
        } else {
            // Rough estimate for other levels
            return barsVisible + 1
        }
    }
    
    // Struct to track when we need to regenerate the cache
    private struct CacheParams: Equatable {
        let zoomLevel: Int
        let effectivePixelsPerBeat: Double
        let timeSignatureBeats: Int
        let totalBars: Int
        let rulerHeight: CGFloat
        let themeId: UUID  // To detect theme changes
    }
    
    // Calculate the total width required to draw the entire ruler
    private var totalWidth: CGFloat {
        let beatsPerBar = Double(timeSignatureBeats)
        let pixelsPerBar = effectivePixelsPerBeat * beatsPerBar
        return CGFloat(totalBars) * CGFloat(pixelsPerBar)
    }
    
    // Constants for optimized rendering
    private let viewportMargin: CGFloat = 300 // Margin to add when determining visible elements
    
    // Line heights for different markers - relative to the ruler height
    private let barLineHeight: CGFloat = 0.4    // Major grid lines (80% of height)
    private let halfBarLineHeight: CGFloat = 0.3 // Half-bar markers (60% of height)
    private let quarterLineHeight: CGFloat = 0.2 // Quarter note markers (40% of height)
    private let eighthLineHeight: CGFloat = 0.15  // Eighth note markers (30% of height)
    private let sixteenthLineHeight: CGFloat = 0.1 // Sixteenth note markers (20% of height)
    
    // Colors for ruler elements - defined once for efficiency
    private var barLineColor: Color { themeManager.gridLineColor.opacity(0.6) } // Match grid opacity
    private var halfBarLineColor: Color { themeManager.gridLineColor.opacity(1.0) } // Match grid opacity
    private var quarterBarLineColor: Color { themeManager.gridLineColor.opacity(1.0) } // Match grid opacity
    private var eighthBarLineColor: Color { themeManager.gridLineColor.opacity(1.0) } // Match grid opacity
    private var sixteenthBarLineColor: Color { themeManager.gridLineColor.opacity(1.0) } // Slightly transparent
    private var textColor: Color { themeManager.primaryTextColor }
    
    // Calculate visible range of bars based on viewport
    private var visibleBarRange: (start: Int, end: Int) {
        let beatsPerBar = Double(timeSignatureBeats)
        let pixelsPerBar = effectivePixelsPerBeat * beatsPerBar
        
        // Calculate the start bar index with viewport margin
        let visibleStartPos = max(0, viewportScrollOffset.x - viewportMargin)
        let startBar = max(0, Int(visibleStartPos / CGFloat(pixelsPerBar)))
        
        // Calculate the end bar index with viewport margin
        let visibleEndPos = viewportScrollOffset.x + viewportWidth + viewportMargin
        let endBar = min(totalBars, Int(ceil(visibleEndPos / CGFloat(pixelsPerBar))) + 1)
        
        return (startBar, endBar)
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // At zoom levels 0-1, use direct Canvas rendering for more precise control
            if zoomLevel <= 1 {
                Canvas { context, size in
                    drawVisibleRulerSection(context: context, size: CGSize(width: totalWidth, height: rulerHeight))
                }
                .drawingGroup(opaque: false)
                .frame(width: totalWidth, height: rulerHeight)
                // Uncomment for debugging
                // .overlay(Text("Text elements: \(textElementCount)").position(x: 100, y: 10))
            }
            // For other zoom levels, use the cached image approach
            else if let cachedImage = cachedRulerImage {
                cachedImage
                    .resizable(resizingMode: .tile)
                    .antialiased(true)
                    .interpolation(.high)
                    .frame(width: totalWidth, height: rulerHeight)
            } else {
                // Draw the ruler if there's no cached image
                Canvas { context, size in
                    drawRuler(context: context, size: CGSize(width: totalWidth, height: rulerHeight))
                }
                .drawingGroup(opaque: false)
                .frame(width: totalWidth, height: rulerHeight)
            }
            
            // Debug info overlay (uncomment for debugging)
            // Text("Bars: \(visibleBarRange.start)-\(visibleBarRange.end) | Text: ~\(textElementCount)")
            //     .font(.system(size: 8))
            //     .foregroundColor(.white)
            //     .background(Color.black.opacity(0.5))
            //     .padding(4)
            //     .position(x: 100, y: 10)
        }
        .onAppear {
            regenerateRulerIfNeeded()
        }
        .onChange(of: zoomLevel) { _, _ in regenerateRulerIfNeeded() }
        .onChange(of: effectivePixelsPerBeat) { _, _ in regenerateRulerIfNeeded() }
        .onChange(of: timeSignatureBeats) { _, _ in regenerateRulerIfNeeded() }
        .onChange(of: totalBars) { _, _ in regenerateRulerIfNeeded() }
        .onChange(of: rulerHeight) { _, _ in regenerateRulerIfNeeded() }
        .onChange(of: themeManager.themeChangeIdentifier) { _, _ in regenerateRulerIfNeeded() }
    }
    
    // Check if we need to regenerate the cached image
    private func regenerateRulerIfNeeded() {
        // Only use cached images for zoom levels > 1
        if zoomLevel <= 1 {
            // For zoom levels 0-1, clear any cached image to ensure we use direct rendering
            cachedRulerImage = nil
            return
        }
        
        let currentParams = CacheParams(
            zoomLevel: zoomLevel,
            effectivePixelsPerBeat: effectivePixelsPerBeat,
            timeSignatureBeats: timeSignatureBeats,
            totalBars: totalBars,
            rulerHeight: rulerHeight,
            themeId: themeManager.themeChangeIdentifier
        )
        
        // Only regenerate if parameters have changed
        if lastCacheParams != currentParams {
            // Use Task to avoid blocking UI
            Task {
                await generateRulerImage()
                lastCacheParams = currentParams
                await MainActor.run {
                    debugInfo = "Cache regen: \(Date())"
                }
            }
        }
    }
    
    // Generate the cached ruler image
    @MainActor
    private func generateRulerImage() async {
        // Skip image generation for zoom levels 0-1
        if zoomLevel <= 1 {
            return
        }
        
        // Get the size of the ruler to render
        let size = CGSize(width: totalWidth, height: rulerHeight)
        
        // If the size is too large or invalid, skip rendering
        guard size.width > 0, size.height > 0, size.width < 16000 else {
            debugInfo = "Size too large: \(size.width) x \(size.height)"
            return
        }
        
        // Create a temporary view that renders our ruler
        let renderer = ImageRenderer(content: 
            Canvas { context, _ in
                drawRuler(context: context, size: size)
            }
            .frame(width: size.width, height: size.height)
        )
        
        // Configure renderer for retina display
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0
        
        // Generate the image
        if let nsImage = renderer.nsImage {
            self.cachedRulerImage = Image(nsImage: nsImage)
            debugInfo = "Image: \(nsImage.size.width) x \(nsImage.size.height)"
        } else {
            debugInfo = "Failed to render"
        }
    }

    // Draw only the visible portion of the ruler for zoom levels 0-1
    private func drawVisibleRulerSection(context: GraphicsContext, size: CGSize) {
        let pixelsPerBeat = effectivePixelsPerBeat
        let beatsPerBar = Double(timeSignatureBeats)
        let pixelsPerBar = pixelsPerBeat * beatsPerBar
        
        // Use the calculated visible range to optimize rendering
        let (startBar, endBar) = visibleBarRange
        
        // Draw ruler markers and numbers based on zoom level
        switch zoomLevel {
        case 0: // Closest zoom
            drawZoomLevel0Ruler(context: context, size: size,
                             startBar: startBar, endBar: endBar,
                             pixelsPerBar: pixelsPerBar, pixelsPerBeat: pixelsPerBeat,
                             beatsPerBar: beatsPerBar)
            
        case 1: // Close zoom
            drawZoomLevel1Ruler(context: context, size: size,
                             startBar: startBar, endBar: endBar,
                             pixelsPerBar: pixelsPerBar, pixelsPerBeat: pixelsPerBeat,
                             beatsPerBar: beatsPerBar)
            
        default:
            // Should not reach here as we use cached images for other zoom levels
            break
        }
    }

    // Main drawing function - for cached image generation
    private func drawRuler(context: GraphicsContext, size: CGSize) {
        let pixelsPerBeat = effectivePixelsPerBeat
        let beatsPerBar = Double(timeSignatureBeats)
        let pixelsPerBar = pixelsPerBeat * beatsPerBar
        
        // Calculate the full range of bars to draw
        let startBar = 0
        let endBar = totalBars // Draw up to the total number of bars

        // Draw ruler markers and numbers based on zoom level
        switch zoomLevel {
        case 0: // Closest zoom (should not reach here)
            drawZoomLevel0Ruler(context: context, size: size,
                             startBar: startBar, endBar: endBar,
                             pixelsPerBar: pixelsPerBar, pixelsPerBeat: pixelsPerBeat,
                             beatsPerBar: beatsPerBar)
            
        case 1: // Close zoom (should not reach here)
            drawZoomLevel1Ruler(context: context, size: size,
                             startBar: startBar, endBar: endBar,
                             pixelsPerBar: pixelsPerBar, pixelsPerBeat: pixelsPerBeat,
                             beatsPerBar: beatsPerBar)
            
        case 2: // Medium-close zoom
            drawZoomLevel2Ruler(context: context, size: size,
                             startBar: startBar, endBar: endBar,
                             pixelsPerBar: pixelsPerBar, pixelsPerBeat: pixelsPerBeat,
                             beatsPerBar: beatsPerBar)
            
        case 3: // Medium zoom
            drawZoomLevel3Ruler(context: context, size: size,
                             startBar: startBar, endBar: endBar,
                             pixelsPerBar: pixelsPerBar, pixelsPerBeat: pixelsPerBeat,
                             beatsPerBar: beatsPerBar)
            
        case 4, 5: // Medium-far zoom
            drawZoomLevel4And5Ruler(context: context, size: size,
                                 startBar: startBar, endBar: endBar,
                                 pixelsPerBar: pixelsPerBar, pixelsPerBeat: pixelsPerBeat,
                                 beatsPerBar: beatsPerBar)
            
        case 6: // Furthest zoom
            drawZoomLevel6Ruler(context: context, size: size,
                             startBar: startBar, endBar: endBar,
                             pixelsPerBar: pixelsPerBar, pixelsPerBeat: pixelsPerBeat,
                             beatsPerBar: beatsPerBar)
            
        default:
            // Default to medium zoom
            drawZoomLevel3Ruler(context: context, size: size,
                             startBar: startBar, endBar: endBar,
                             pixelsPerBar: pixelsPerBar, pixelsPerBeat: pixelsPerBeat,
                             beatsPerBar: beatsPerBar)
        }
    }

    // MARK: - Helper method to draw a line from bottom
    
    private func drawLineFromBottom(
        context: GraphicsContext,
        at x: CGFloat,
        height: CGFloat,
        size: CGSize,
        color: Color,
        lineWidth: CGFloat
    ) {
        // Ensure x is within the canvas bounds before drawing
        guard x >= 0 && x <= size.width else { return }
        
        let linePath = Path { path in
            // Start from the bottom of the view
            path.move(to: CGPoint(x: x, y: size.height))
            // Draw upward to the specified height
            path.addLine(to: CGPoint(x: x, y: size.height - height))
        }
        
        // Draw the line
        context.stroke(linePath, with: .color(color), lineWidth: lineWidth)
    }
    
    // MARK: - Zoom Level Drawing Functions (Modified: removed scrollX)

    // MARK: - Zoom Level 0 (Closest)
    private func drawZoomLevel0Ruler(
        context: GraphicsContext,
        size: CGSize,
        startBar: Int,
        endBar: Int,
        pixelsPerBar: Double,
        pixelsPerBeat: Double,
        beatsPerBar: Double
    ) {
        // Define a threshold for showing beat numbers. Adjust as needed.
        let showBeatNumbersThreshold: Double = 30 // Only show ".1, .2" if pixelsPerBeat > 30
        
        // Local counter for tracking - NOT modifying state
        var textDrawCount = 0
        
        // Calculate visible area with margins
        let visibleStart = viewportScrollOffset.x - viewportMargin
        let visibleEnd = viewportScrollOffset.x + viewportWidth + viewportMargin
        
        // Create a separate text context to batch text rendering
        var textElements: [(text: String, position: CGRect)] = []
        
        // Draw quarter beat lines and numbers
        for barIndex in startBar..<endBar { // Only draw visible bars
            for beat in 0..<Int(beatsPerBar) {
                let beatPosition = Double(barIndex) * beatsPerBar + Double(beat)
                // Calculate x position relative to the start (0)
                let x = CGFloat(beatPosition) * CGFloat(pixelsPerBeat)
                
                // Skip drawing if outside the visible area +/- margin
                if x < visibleStart || x > visibleEnd {
                    continue
                }
                
                // Quarter note line
                let isBarLine = beat == 0
                let lineHeight = isBarLine ?
                    size.height * barLineHeight :
                    size.height * quarterLineHeight
                
                drawLineFromBottom(
                    context: context, at: x, height: lineHeight, size: size,
                    color: isBarLine ? barLineColor : quarterBarLineColor,
                    lineWidth: isBarLine ? 1.2 : 0.8
                )
                
                // Draw bar number or beat number (conditionally)
                let barNum = barIndex + 1
                let isBarStart = (beat == 0)
                
                // Always draw the main bar number
                if isBarStart {
                    let displayText = "\(barNum)"
                    let textRect = CGRect(x: x + 4, y: 2, width: 100, height: 14)
                    if textRect.minX < size.width {
                        // Add to batch instead of drawing immediately
                        textElements.append((displayText, textRect))
                        textDrawCount += 1 // Increment counter (local var, not state)
                    }
                } 
                // Only draw beat numbers if not the start of the bar AND space permits
                else if pixelsPerBeat > showBeatNumbersThreshold {
                    let displayText = "\(barNum).\(beat + 1)"
                    let textRect = CGRect(x: x + 4, y: 2, width: 100, height: 14)
                    if textRect.minX < size.width {
                        // Add to batch instead of drawing immediately
                        textElements.append((displayText, textRect))
                        textDrawCount += 1 // Increment counter (local var, not state)
                    }
                }
                
                // Draw eighth notes between quarter notes
                if beat < Int(beatsPerBar) {
                    let eighthPosition = beatPosition + 0.5
                    let eighthX = CGFloat(eighthPosition) * CGFloat(pixelsPerBeat)
                    
                    // Skip drawing if outside the visible area +/- margin
                    if eighthX >= visibleStart && eighthX <= visibleEnd {
                        drawLineFromBottom(
                            context: context, at: eighthX, height: size.height * eighthLineHeight, size: size,
                            color: eighthBarLineColor, lineWidth: 0.7
                        )
                    }
                }
            }
        }
        
        // Draw the line for the very last bar if needed and if it's visible
        let lastBarPosition = Double(endBar) * beatsPerBar
        let lastBarX = CGFloat(lastBarPosition) * CGFloat(pixelsPerBeat)
        
        if lastBarX >= visibleStart && lastBarX <= visibleEnd {
            drawLineFromBottom(context: context, at: lastBarX, height: size.height * barLineHeight, size: size, color: barLineColor, lineWidth: 1.2)
            
            let lastBarNum = endBar + 1
            let textRect = CGRect(x: lastBarX + 4, y: 2, width: 100, height: 14)
            if textRect.minX < size.width {
                // Add to batch instead of drawing immediately
                textElements.append(("\(lastBarNum)", textRect))
                textDrawCount += 1 // Increment counter (local var, not state)
            }
        }
        
        // Now draw all text elements in one batch with the same style
        let textStyle = context.resolve(Text("").font(.system(size: 10)).foregroundColor(textColor))
        
        // Batch process text rendering
        for (displayText, textRect) in textElements {
            let resolvedText = context.resolve(Text(displayText).font(.system(size: 10)).foregroundColor(textColor))
            context.draw(resolvedText, in: textRect)
        }
        
        // DO NOT update state directly from here
        // textElementsDrawn = textDrawCount  // Removed this line
    }
    
    // MARK: - Zoom Level 1
    private func drawZoomLevel1Ruler(
        context: GraphicsContext, size: CGSize, startBar: Int, endBar: Int,
        pixelsPerBar: Double, pixelsPerBeat: Double, beatsPerBar: Double
    ) {
        // Similar visibility optimization as in zoom level 0
        let visibleStart = viewportScrollOffset.x - viewportMargin
        let visibleEnd = viewportScrollOffset.x + viewportWidth + viewportMargin
        
        // Create a batch for text elements
        var textElements: [(text: String, position: CGRect)] = []
        
        for barIndex in startBar..<endBar {
            let barPosition = Double(barIndex) * beatsPerBar
            let x = CGFloat(barPosition) * CGFloat(pixelsPerBeat)
            
            // Skip if outside visible area
            if x < visibleStart || x > visibleEnd {
                continue
            }
            
            drawLineFromBottom(
                context: context, at: x, height: size.height * barLineHeight, size: size,
                color: barLineColor, lineWidth: 1.2
            )
            
            let barNum = barIndex + 1
            let textRect = CGRect(x: x + 4, y: 2, width: 100, height: 14)
            if textRect.minX < size.width {
                textElements.append(("\(barNum)", textRect))
            }
            
            for beatOffset in [0.25, 0.5, 0.75] {
                let beatPosition = barPosition + beatOffset * beatsPerBar
                let quarterX = CGFloat(beatPosition) * CGFloat(pixelsPerBeat)
                
                // Skip if outside visible area
                if quarterX < visibleStart || quarterX > visibleEnd {
                    continue
                }
                
                let lineHeight = beatOffset == 0.5 ? size.height * halfBarLineHeight : size.height * quarterLineHeight
                let lineColor = beatOffset == 0.5 ? halfBarLineColor : quarterBarLineColor
                drawLineFromBottom(
                    context: context, at: quarterX, height: lineHeight, size: size,
                    color: lineColor, lineWidth: beatOffset == 0.5 ? 0.9 : 0.7
                )
            }
        }
        
        // Draw the line for the very last bar if needed and if it's visible
        let lastBarPosition = Double(endBar) * beatsPerBar
        let lastBarX = CGFloat(lastBarPosition) * CGFloat(pixelsPerBeat)
        
        if lastBarX >= visibleStart && lastBarX <= visibleEnd {
            drawLineFromBottom(context: context, at: lastBarX, height: size.height * barLineHeight, size: size, color: barLineColor, lineWidth: 1.2)
            
            let lastBarNum = endBar + 1
            let textRect = CGRect(x: lastBarX + 4, y: 2, width: 100, height: 14)
            if textRect.minX < size.width {
                textElements.append(("\(lastBarNum)", textRect))
            }
        }
        
        // Batch draw all text
        for (displayText, textRect) in textElements {
            let resolvedText = context.resolve(Text(displayText).font(.system(size: 10)).foregroundColor(textColor))
            context.draw(resolvedText, in: textRect)
        }
        
        // DO NOT update state directly from here
        // textElementsDrawn = textElements.count  // Removed this line
    }
    
    // MARK: - Zoom Level 2 & 3 (Combined logic as they are similar)
    private func drawZoomLevel2Ruler(
        context: GraphicsContext, size: CGSize, startBar: Int, endBar: Int,
        pixelsPerBar: Double, pixelsPerBeat: Double, beatsPerBar: Double
    ) {
        drawZoomLevel3Ruler(context: context, size: size, startBar: startBar, endBar: endBar, pixelsPerBar: pixelsPerBar, pixelsPerBeat: pixelsPerBeat, beatsPerBar: beatsPerBar)
    }
    
    private func drawZoomLevel3Ruler(
        context: GraphicsContext, size: CGSize, startBar: Int, endBar: Int,
        pixelsPerBar: Double, pixelsPerBeat: Double, beatsPerBar: Double
    ) {
        for barIndex in startBar..<endBar {
            let barPosition = Double(barIndex) * beatsPerBar
            let x = CGFloat(barPosition) * CGFloat(pixelsPerBeat)
            
            drawLineFromBottom(
                context: context, at: x, height: size.height * barLineHeight, size: size,
                color: barLineColor, lineWidth: 1.2
            )
            
            let barNum = barIndex + 1
            let textRect = CGRect(x: x + 4, y: 2, width: 100, height: 14)
            if textRect.minX < size.width {
                 context.draw(Text("\(barNum)").font(.system(size: 10)).foregroundColor(textColor), in: textRect)
            }
            
            let halfBarPosition = barPosition + beatsPerBar / 2
            let halfBarX = CGFloat(halfBarPosition) * CGFloat(pixelsPerBeat)
            drawLineFromBottom(
                context: context, at: halfBarX, height: size.height * halfBarLineHeight, size: size,
                color: halfBarLineColor, lineWidth: 0.9
            )
        }
        // Draw the line for the very last bar if needed
        let lastBarPosition = Double(endBar) * beatsPerBar
        let lastBarX = CGFloat(lastBarPosition) * CGFloat(pixelsPerBeat)
        drawLineFromBottom(context: context, at: lastBarX, height: size.height * barLineHeight, size: size, color: barLineColor, lineWidth: 1.2)
        let lastBarNum = endBar + 1
        let textRect = CGRect(x: lastBarX + 4, y: 2, width: 100, height: 14)
        if textRect.minX < size.width {
             context.draw(Text("\(lastBarNum)").font(.system(size: 10)).foregroundColor(textColor), in: textRect)
        }
    }
    
    // MARK: - Zoom Level 4-5
    private func drawZoomLevel4And5Ruler(
        context: GraphicsContext, size: CGSize, startBar: Int, endBar: Int,
        pixelsPerBar: Double, pixelsPerBeat: Double, beatsPerBar: Double
    ) {
        for barIndex in stride(from: startBar, to: endBar, by: 2) { // Use 'to' instead of 'through'
            let barPosition = Double(barIndex) * beatsPerBar
            let x = CGFloat(barPosition) * CGFloat(pixelsPerBeat)
            
            drawLineFromBottom(
                context: context, at: x, height: size.height * barLineHeight, size: size,
                color: barLineColor, lineWidth: 1.2
            )
            
            let barNum = barIndex + 1
            let textRect = CGRect(x: x + 4, y: 2, width: 100, height: 14)
            if textRect.minX < size.width {
                context.draw(Text("\(barNum)").font(.system(size: 10)).foregroundColor(textColor), in: textRect)
            }
            
            // Draw intermediate bar line
            if barIndex + 1 < endBar {
                let midBarPosition = barPosition + beatsPerBar
                let midBarX = CGFloat(midBarPosition) * CGFloat(pixelsPerBeat)
                drawLineFromBottom(
                    context: context, at: midBarX, height: size.height * halfBarLineHeight, size: size,
                    color: halfBarLineColor, lineWidth: 0.9
                )
            }
        }
         // Draw the line for the very last bar if needed and if it's a major interval
        if endBar % 2 == 0 {
            let lastBarPosition = Double(endBar) * beatsPerBar
            let lastBarX = CGFloat(lastBarPosition) * CGFloat(pixelsPerBeat)
            drawLineFromBottom(context: context, at: lastBarX, height: size.height * barLineHeight, size: size, color: barLineColor, lineWidth: 1.2)
            let lastBarNum = endBar + 1
            let textRect = CGRect(x: lastBarX + 4, y: 2, width: 100, height: 14)
            if textRect.minX < size.width {
                context.draw(Text("\(lastBarNum)").font(.system(size: 10)).foregroundColor(textColor), in: textRect)
            }
        } else if endBar > 0 { // Draw the intermediate line if last bar is odd
             let lastMidBarPosition = Double(endBar - 1) * beatsPerBar + beatsPerBar
             let lastMidBarX = CGFloat(lastMidBarPosition) * CGFloat(pixelsPerBeat)
             drawLineFromBottom(context: context, at: lastMidBarX, height: size.height * halfBarLineHeight, size: size, color: halfBarLineColor, lineWidth: 0.9)
        }
    }
    
    // MARK: - Zoom Level 6 (Furthest)
    private func drawZoomLevel6Ruler(
        context: GraphicsContext, size: CGSize, startBar: Int, endBar: Int,
        pixelsPerBar: Double, pixelsPerBeat: Double, beatsPerBar: Double
    ) {
        for barIndex in stride(from: startBar, to: endBar, by: 4) {
            let barPosition = Double(barIndex) * beatsPerBar
            let x = CGFloat(barPosition) * CGFloat(pixelsPerBeat)
            
            drawLineFromBottom(
                context: context, at: x, height: size.height * barLineHeight, size: size,
                color: barLineColor, lineWidth: 1.2
            )
            
            let barNum = barIndex + 1
            let textRect = CGRect(x: x + 4, y: 2, width: 100, height: 14)
            if textRect.minX < size.width {
                context.draw(Text("\(barNum)").font(.system(size: 10)).foregroundColor(textColor), in: textRect)
            }
            
            // Draw 2-bar marker line
            if barIndex + 2 < endBar {
                let twoBarPosition = barPosition + 2 * beatsPerBar
                let twoBarX = CGFloat(twoBarPosition) * CGFloat(pixelsPerBeat)
                drawLineFromBottom(
                    context: context, at: twoBarX, height: size.height * halfBarLineHeight, size: size,
                    color: halfBarLineColor, lineWidth: 0.9
                )
            }
        }
        // Draw the line for the very last bar if needed and if it's a major interval
        if endBar % 4 == 0 {
            let lastBarPosition = Double(endBar) * beatsPerBar
            let lastBarX = CGFloat(lastBarPosition) * CGFloat(pixelsPerBeat)
            drawLineFromBottom(context: context, at: lastBarX, height: size.height * barLineHeight, size: size, color: barLineColor, lineWidth: 1.2)
             let lastBarNum = endBar + 1
             let textRect = CGRect(x: lastBarX + 4, y: 2, width: 100, height: 14)
             if textRect.minX < size.width {
                  context.draw(Text("\(lastBarNum)").font(.system(size: 10)).foregroundColor(textColor), in: textRect)
             }
        } else if endBar >= 2 && (endBar - 2) % 4 == 0 { // Draw the intermediate line if needed
             let lastTwoBarPosition = Double(endBar - 2) * beatsPerBar + 2 * beatsPerBar
             let lastTwoBarX = CGFloat(lastTwoBarPosition) * CGFloat(pixelsPerBeat)
             drawLineFromBottom(context: context, at: lastTwoBarX, height: size.height * halfBarLineHeight, size: size, color: halfBarLineColor, lineWidth: 0.9)
        }
    }
}
