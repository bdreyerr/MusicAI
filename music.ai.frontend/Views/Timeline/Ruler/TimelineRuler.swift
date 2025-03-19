import SwiftUI

/// TimelineRuler shows bar, beat, and division markers at the top of the timeline
/// It adjusts what it displays based on the current zoom level
struct TimelineRuler: View {
    @ObservedObject var state: TimelineStateViewModel
    @ObservedObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var themeManager: ThemeManager
    let width: CGFloat
    let height: CGFloat
    
    // Add typealias for easier reference to GridDivision enum
    private typealias GridDivision = TimelineStateViewModel.GridDivision
    
    // Constants for optimized rendering
    private let viewportMargin: CGFloat = 100
    
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
    
    // Variables to handle hover state for buttons
    @State private var isHoveringTimeline: Bool = false
    @State private var showingGridOptions: Bool = false
    
    // Button positioning - center horizontally by default
    private var buttonPositionX: CGFloat {
        width / 2
    }
    
    // Label for displaying the current grid division
    private var gridDivisionLabel: String {
        switch state.gridDivision {
        case .sixteenth: return "1/16"
        case .eighth: return "1/8"
        case .quarter: return "1/4"
        case .half: return "1/2"
        case .bar: return "Bar"
        case .twoBar: return "2 Bar"
        case .fourBar: return "4 Bar"
        }
    }
    
    var body: some View {
        ZStack(alignment: .top) { // Use ZStack to overlay components instead of stacking them vertically
            // Use GeometryReader to get the exact size
            GeometryReader { geo in
                Canvas { context, size in
                    // Skip drawing if dimensions are invalid
                    guard size.width > 0, size.height > 0 else { return }
                    
                    // Draw the ruler based on current zoom level
                    drawRuler(context: context, size: size)
                }
                .frame(width: width, height: height)
                .id("ruler-\(state.zoomLevel)-\(state.isScrolling ? "scrolling" : "static")-\(Int(state.scrollOffset.x/100))")
                .drawingGroup(opaque: false) // Use Metal acceleration
                
                // Add tap gesture to seek playhead
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        TapGesture()
                            .onEnded { _ in
                                handleRulerTap(at: geo.frame(in: .global))
                            }
                    )
                    .onHover { hovering in
                        isHoveringTimeline = hovering
                    }
            }
            
            // Buttons for grid snap and zoom (positioned with ZStack)
            HStack(spacing: 12) {
                // Grid snap button
                Button(action: {
                    showingGridOptions = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.grid.3x3")
                            .font(.system(size: 11))
                        Text(gridDivisionLabel)
                            .font(.system(size: 11))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(themeManager.secondaryBackgroundColor.opacity(0.9))
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(themeManager.borderColor, lineWidth: 1)
                    )
                }
                .buttonStyle(BorderlessButtonStyle())
                .popover(isPresented: $showingGridOptions) {
                    VStack(spacing: 8) {
                        Text("Grid Division")
                            .font(.headline)
                            .padding(.top, 8)
                        
                        Divider()
                        
                        ForEach(GridDivision.allCases, id: \.self) { division in
                            Button(action: {
                                // Use DispatchQueue.main.async to prevent state updates during view update
                                DispatchQueue.main.async {
                                    // Set zoom level based on the selected grid division
                                    state.setZoomLevelForGridDivision(division)
                                    showingGridOptions = false
                                }
                            }) {
                                HStack {
                                    Text(division.description)
                                        .frame(width: 100, alignment: .leading)
                                    Spacer()
                                    if state.gridDivision == division {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                        }
                    }
                    .frame(width: 150)
                    .padding(.bottom, 8)
                }
                
                // Zoom buttons
                HStack(spacing: 2) {
                    Button(action: {
                        // Use DispatchQueue.main.async to prevent state updates during view update
                        DispatchQueue.main.async {
                            state.zoomOut()
                        }
                    }) {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(themeManager.secondaryBackgroundColor.opacity(0.9))
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(themeManager.borderColor, lineWidth: 1)
                    )
                    
                    Button(action: {
                        // Use DispatchQueue.main.async to prevent state updates during view update
                        DispatchQueue.main.async {
                            state.zoomIn()
                        }
                    }) {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(themeManager.secondaryBackgroundColor.opacity(0.9))
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(themeManager.borderColor, lineWidth: 1)
                    )
                }
            }
            .position(x: buttonPositionX, y: height - 10) // Positioned within the ZStack
            .opacity(isHoveringTimeline ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.2), value: isHoveringTimeline)
        }
        .frame(height: height) // Set a fixed height for the entire ruler component
    }
    
    private func handleRulerTap(at frame: CGRect) {
        guard let event = NSApp.currentEvent else { return }
        
        // Convert the click location to beat position
        let position = event.locationInWindow
        let xPosition = position.x - frame.minX + state.scrollOffset.x
        let rawBeatPosition = xPosition / CGFloat(state.effectivePixelsPerBeat)
        
        // Ensure we have a valid position
        guard rawBeatPosition >= 0 else { return }
        
        // Snap to nearest grid marker
        let snappedBeatPosition = snapToNearestGridMarker(rawBeatPosition)
        
        // Seek to the beat position
        projectViewModel.seekToBeat(snappedBeatPosition)
    }
    
    // Snap a beat position to the appropriate grid division based on zoom level
    private func snapToNearestGridMarker(_ rawBeatPosition: Double) -> Double {
        // Determine the smallest visible grid division based on zoom level
        let timeSignature = projectViewModel.timeSignatureBeats
        
        switch state.gridDivision {
        case .sixteenth:
            // Snap to sixteenth notes (0.0625 beat)
            return round(rawBeatPosition * 16.0) / 16.0
            
        case .eighth:
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
            
            // Check if we're closer to the start or middle of the bar
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
            
        case .bar:
            // When zoomed out, snap to bars
            let beatsPerBar = Double(timeSignature)
            return round(rawBeatPosition / beatsPerBar) * beatsPerBar
            
        case .twoBar:
            // When zoomed way out, snap to every two bars
            let beatsPerTwoBars = Double(timeSignature) * 2.0
            return round(rawBeatPosition / beatsPerTwoBars) * beatsPerTwoBars
            
        case .fourBar:
            // When zoomed way out, snap to every four bars
            let beatsPerFourBars = Double(timeSignature) * 4.0
            return round(rawBeatPosition / beatsPerFourBars) * beatsPerFourBars
        }
    }
    
    // Main drawing function
    private func drawRuler(context: GraphicsContext, size: CGSize) {
        // Get current view state
        let scrollX = state.scrollOffset.x
        let pixelsPerBeat = state.effectivePixelsPerBeat
        let beatsPerBar = Double(projectViewModel.timeSignatureBeats)
        let pixelsPerBar = pixelsPerBeat * beatsPerBar
        
        // Calculate visible range with margin
        let startX = max(0, scrollX - viewportMargin)
        let endX = scrollX + size.width + viewportMargin
        let startBar = Int(floor(startX / pixelsPerBar))
        let endBar = Int(ceil(endX / pixelsPerBar)) + 1
        
        // Draw ruler markers and numbers based on zoom level
        switch state.zoomLevel {
        case 0: // Closest zoom
            // Lines at quarter positions, shorter lines at eighths, numbers at quarters
            drawZoomLevel0Ruler(context: context, size: size, 
                             startBar: startBar, endBar: endBar,
                             pixelsPerBar: pixelsPerBar, pixelsPerBeat: pixelsPerBeat,
                             beatsPerBar: beatsPerBar, scrollX: scrollX)
            
        case 1: // Close zoom
            // Lines at bars, shorter lines at quarters, numbers at bars
            drawZoomLevel1Ruler(context: context, size: size, 
                             startBar: startBar, endBar: endBar,
                             pixelsPerBar: pixelsPerBar, pixelsPerBeat: pixelsPerBeat,
                             beatsPerBar: beatsPerBar, scrollX: scrollX)
            
        case 2: // Medium-close zoom
            // Lines at bars, shorter lines at halves, numbers at bars
            drawZoomLevel2Ruler(context: context, size: size, 
                             startBar: startBar, endBar: endBar,
                             pixelsPerBar: pixelsPerBar, pixelsPerBeat: pixelsPerBeat,
                             beatsPerBar: beatsPerBar, scrollX: scrollX)
            
        case 3: // Medium zoom
            // Lines at bars, shorter lines at halves, numbers at bars
            drawZoomLevel3Ruler(context: context, size: size, 
                             startBar: startBar, endBar: endBar,
                             pixelsPerBar: pixelsPerBar, pixelsPerBeat: pixelsPerBeat,
                             beatsPerBar: beatsPerBar, scrollX: scrollX)
            
        case 4, 5: // Medium-far zoom
            // Lines at 2 bars, shorter lines at bars, numbers at 2 bars
            drawZoomLevel4And5Ruler(context: context, size: size, 
                                 startBar: startBar, endBar: endBar,
                                 pixelsPerBar: pixelsPerBar, pixelsPerBeat: pixelsPerBeat,
                                 beatsPerBar: beatsPerBar, scrollX: scrollX)
            
        case 6: // Furthest zoom
            // Lines at 4 bars, shorter lines at 2 bars, numbers at 4 bars
            drawZoomLevel6Ruler(context: context, size: size, 
                             startBar: startBar, endBar: endBar,
                             pixelsPerBar: pixelsPerBar, pixelsPerBeat: pixelsPerBeat,
                             beatsPerBar: beatsPerBar, scrollX: scrollX)
            
        default:
            // Default to medium zoom
            drawZoomLevel3Ruler(context: context, size: size, 
                             startBar: startBar, endBar: endBar,
                             pixelsPerBar: pixelsPerBar, pixelsPerBeat: pixelsPerBeat,
                             beatsPerBar: beatsPerBar, scrollX: scrollX)
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
        let linePath = Path { path in
            // Start from the bottom of the view
            path.move(to: CGPoint(x: x, y: size.height))
            // Draw upward to the specified height
            path.addLine(to: CGPoint(x: x, y: size.height - height))
        }
        
        // Draw the line
        context.stroke(linePath, with: .color(color), lineWidth: lineWidth)
    }
    
    // MARK: - Zoom Level 0 (Closest)
    private func drawZoomLevel0Ruler(
        context: GraphicsContext, 
        size: CGSize,
        startBar: Int, 
        endBar: Int,
        pixelsPerBar: Double, 
        pixelsPerBeat: Double,
        beatsPerBar: Double, 
        scrollX: CGFloat
    ) {
        // Draw quarter beat lines and numbers
        for barIndex in startBar...endBar {
            for beat in 0..<Int(beatsPerBar) {
                let beatPosition = Double(barIndex) * beatsPerBar + Double(beat)
                let x = CGFloat(beatPosition) * CGFloat(pixelsPerBeat) - scrollX
                
                // Only draw if within viewport with margin
                if x >= -viewportMargin && x <= size.width + viewportMargin {
                    // Quarter note line - determine height based on if it's a bar line
                    let isBarLine = beat == 0
                    let lineHeight = isBarLine ? 
                        size.height * barLineHeight : 
                        size.height * quarterLineHeight
                    
                    // Draw the line from the bottom
                    drawLineFromBottom(
                        context: context,
                        at: x,
                        height: lineHeight,
                        size: size,
                        color: isBarLine ? barLineColor : quarterBarLineColor,
                        lineWidth: isBarLine ? 1.2 : 0.8
                    )
                    
                    // Draw bar number or beat number near the top
                    let barNum = barIndex + 1 // Display 1-based bar numbers
                    let displayText = beat == 0 ? "\(barNum)" : "\(barNum).\(beat + 1)"
                    
                    let textRect = CGRect(x: x + 4, y: 2, width: 100, height: 14)
                    context.draw(Text(displayText).font(.system(size: 10)).foregroundColor(textColor),
                               in: textRect)
                }
                
                // Draw eighth notes between quarter notes as short lines
                if beat < Int(beatsPerBar) {
                    let eighthPosition = beatPosition + 0.5
                    let eighthX = CGFloat(eighthPosition) * CGFloat(pixelsPerBeat) - scrollX
                    
                    if eighthX >= -viewportMargin && eighthX <= size.width + viewportMargin {
                        // Draw short line for eighth note marker
                        drawLineFromBottom(
                            context: context,
                            at: eighthX,
                            height: size.height * eighthLineHeight,
                            size: size,
                            color: eighthBarLineColor,
                            lineWidth: 0.7
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Zoom Level 1
    private func drawZoomLevel1Ruler(
        context: GraphicsContext, 
        size: CGSize,
        startBar: Int, 
        endBar: Int,
        pixelsPerBar: Double, 
        pixelsPerBeat: Double,
        beatsPerBar: Double, 
        scrollX: CGFloat
    ) {
        // Draw bar lines and numbers
        for barIndex in startBar...endBar {
            let barPosition = Double(barIndex) * beatsPerBar
            let x = CGFloat(barPosition) * CGFloat(pixelsPerBeat) - scrollX
            
            // Only draw if within viewport with margin
            if x >= -viewportMargin && x <= size.width + viewportMargin {
                // Bar line - draw from bottom
                drawLineFromBottom(
                    context: context,
                    at: x,
                    height: size.height * barLineHeight,
                    size: size,
                    color: barLineColor,
                    lineWidth: 1.2
                )
                
                // Draw bar number
                let barNum = barIndex + 1 // Display 1-based bar numbers
                let textRect = CGRect(x: x + 4, y: 2, width: 100, height: 14)
                context.draw(Text("\(barNum)").font(.system(size: 10)).foregroundColor(textColor),
                           in: textRect)
            }
            
            // Draw short lines at quarter positions within the bar
            for beatOffset in [0.25, 0.5, 0.75] {
                let beatPosition = barPosition + beatOffset * beatsPerBar
                let quarterX = CGFloat(beatPosition) * CGFloat(pixelsPerBeat) - scrollX
                
                if quarterX >= -viewportMargin && quarterX <= size.width + viewportMargin {
                    // Draw shorter line for beat markers
                    let lineHeight = beatOffset == 0.5 ? size.height * halfBarLineHeight : size.height * quarterLineHeight
                    let lineColor = beatOffset == 0.5 ? halfBarLineColor : quarterBarLineColor
                    
                    drawLineFromBottom(
                        context: context,
                        at: quarterX,
                        height: lineHeight,
                        size: size,
                        color: lineColor,
                        lineWidth: beatOffset == 0.5 ? 0.9 : 0.7
                    )
                }
            }
        }
    }
    
    // MARK: - Zoom Level 2
    private func drawZoomLevel2Ruler(
        context: GraphicsContext, 
        size: CGSize,
        startBar: Int, 
        endBar: Int,
        pixelsPerBar: Double, 
        pixelsPerBeat: Double,
        beatsPerBar: Double, 
        scrollX: CGFloat
    ) {
        // Draw bar lines and numbers
        for barIndex in startBar...endBar {
            let barPosition = Double(barIndex) * beatsPerBar
            let x = CGFloat(barPosition) * CGFloat(pixelsPerBeat) - scrollX
            
            // Only draw if within viewport with margin
            if x >= -viewportMargin && x <= size.width + viewportMargin {
                // Bar line - draw from bottom
                drawLineFromBottom(
                    context: context,
                    at: x,
                    height: size.height * barLineHeight,
                    size: size,
                    color: barLineColor,
                    lineWidth: 1.2
                )
                
                // Draw bar number
                let barNum = barIndex + 1 // Display 1-based bar numbers
                let textRect = CGRect(x: x + 4, y: 2, width: 100, height: 14)
                context.draw(Text("\(barNum)").font(.system(size: 10)).foregroundColor(textColor),
                           in: textRect)
            }
            
            // Draw shorter line at half bar position
            let halfBarPosition = barPosition + beatsPerBar / 2
            let halfBarX = CGFloat(halfBarPosition) * CGFloat(pixelsPerBeat) - scrollX
            
            if halfBarX >= -viewportMargin && halfBarX <= size.width + viewportMargin {
                // Draw shorter line for half-bar marker
                drawLineFromBottom(
                    context: context,
                    at: halfBarX,
                    height: size.height * halfBarLineHeight,
                    size: size,
                    color: halfBarLineColor,
                    lineWidth: 0.9
                )
            }
        }
    }
    
    // MARK: - Zoom Level 3
    private func drawZoomLevel3Ruler(
        context: GraphicsContext, 
        size: CGSize,
        startBar: Int, 
        endBar: Int,
        pixelsPerBar: Double, 
        pixelsPerBeat: Double,
        beatsPerBar: Double, 
        scrollX: CGFloat
    ) {
        // Draw bar lines and numbers
        for barIndex in startBar...endBar {
            let barPosition = Double(barIndex) * beatsPerBar
            let x = CGFloat(barPosition) * CGFloat(pixelsPerBeat) - scrollX
            
            // Only draw if within viewport with margin
            if x >= -viewportMargin && x <= size.width + viewportMargin {
                // Bar line - draw from bottom
                drawLineFromBottom(
                    context: context,
                    at: x,
                    height: size.height * barLineHeight,
                    size: size,
                    color: barLineColor,
                    lineWidth: 1.2
                )
                
                // Draw bar number
                let barNum = barIndex + 1 // Display 1-based bar numbers
                let textRect = CGRect(x: x + 4, y: 2, width: 100, height: 14)
                context.draw(Text("\(barNum)").font(.system(size: 10)).foregroundColor(textColor),
                           in: textRect)
            }
            
            // Draw shorter line at half bar position
            let halfBarPosition = barPosition + beatsPerBar / 2
            let halfBarX = CGFloat(halfBarPosition) * CGFloat(pixelsPerBeat) - scrollX
            
            if halfBarX >= -viewportMargin && halfBarX <= size.width + viewportMargin {
                // Draw shorter line for half-bar marker
                drawLineFromBottom(
                    context: context,
                    at: halfBarX,
                    height: size.height * halfBarLineHeight,
                    size: size,
                    color: halfBarLineColor,
                    lineWidth: 0.9
                )
            }
        }
    }
    
    // MARK: - Zoom Level 4-5
    private func drawZoomLevel4And5Ruler(
        context: GraphicsContext, 
        size: CGSize,
        startBar: Int, 
        endBar: Int,
        pixelsPerBar: Double, 
        pixelsPerBeat: Double,
        beatsPerBar: Double, 
        scrollX: CGFloat
    ) {
        // Draw lines at 2-bar intervals and numbers at 2-bar intervals
        for barIndex in stride(from: startBar, through: endBar, by: 2) {
            let barPosition = Double(barIndex) * beatsPerBar
            let x = CGFloat(barPosition) * CGFloat(pixelsPerBeat) - scrollX
            
            // Only draw if within viewport with margin
            if x >= -viewportMargin && x <= size.width + viewportMargin {
                // 2-Bar line - draw from bottom
                drawLineFromBottom(
                    context: context,
                    at: x,
                    height: size.height * barLineHeight,
                    size: size,
                    color: barLineColor,
                    lineWidth: 1.2
                )
                
                // Draw bar number
                let barNum = barIndex + 1 // Display 1-based bar numbers
                let textRect = CGRect(x: x + 4, y: 2, width: 100, height: 14)
                context.draw(Text("\(barNum)").font(.system(size: 10)).foregroundColor(textColor),
                           in: textRect)
            }
            
            // Draw shorter line at the intermediate bar position
            if barIndex + 1 <= endBar {
                let midBarPosition = barPosition + beatsPerBar
                let midBarX = CGFloat(midBarPosition) * CGFloat(pixelsPerBeat) - scrollX
                
                if midBarX >= -viewportMargin && midBarX <= size.width + viewportMargin {
                    // Draw shorter line for intermediate bar
                    drawLineFromBottom(
                        context: context,
                        at: midBarX,
                        height: size.height * halfBarLineHeight,
                        size: size,
                        color: halfBarLineColor,
                        lineWidth: 0.9
                    )
                }
            }
        }
    }
    
    // MARK: - Zoom Level 6 (Furthest)
    private func drawZoomLevel6Ruler(
        context: GraphicsContext, 
        size: CGSize,
        startBar: Int, 
        endBar: Int,
        pixelsPerBar: Double, 
        pixelsPerBeat: Double,
        beatsPerBar: Double, 
        scrollX: CGFloat
    ) {
        // Draw lines at 4-bar intervals and numbers at 4-bar intervals
        for barIndex in stride(from: startBar, through: endBar, by: 4) {
            let barPosition = Double(barIndex) * beatsPerBar
            let x = CGFloat(barPosition) * CGFloat(pixelsPerBeat) - scrollX
            
            // Only draw if within viewport with margin
            if x >= -viewportMargin && x <= size.width + viewportMargin {
                // 4-Bar line - draw from bottom
                drawLineFromBottom(
                    context: context,
                    at: x,
                    height: size.height * barLineHeight,
                    size: size,
                    color: barLineColor,
                    lineWidth: 1.2
                )
                
                // Draw bar number
                let barNum = barIndex + 1 // Display 1-based bar numbers
                let textRect = CGRect(x: x + 4, y: 2, width: 100, height: 14)
                context.draw(Text("\(barNum)").font(.system(size: 10)).foregroundColor(textColor),
                           in: textRect)
            }
            
            // Draw shorter line at the 2-bar offset position
            if barIndex + 2 <= endBar {
                let twoBarPosition = barPosition + 2 * beatsPerBar
                let twoBarX = CGFloat(twoBarPosition) * CGFloat(pixelsPerBeat) - scrollX
                
                if twoBarX >= -viewportMargin && twoBarX <= size.width + viewportMargin {
                    // Draw shorter line for two-bar marker
                    drawLineFromBottom(
                        context: context,
                        at: twoBarX,
                        height: size.height * halfBarLineHeight,
                        size: size,
                        color: halfBarLineColor,
                        lineWidth: 0.9
                    )
                }
            }
        }
    }
}

#Preview {
    TimelineRuler(
        state: TimelineStateViewModel(),
        projectViewModel: ProjectViewModel(),
        width: 800,
        height: 25
    )
    .environmentObject(ThemeManager())
} 
