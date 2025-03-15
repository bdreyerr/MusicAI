import SwiftUI

/// Ruler component that displays bar and beat markers at the top of the timeline
struct TimelineRuler: View {
    @ObservedObject var state: TimelineStateViewModel
    @ObservedObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var themeManager: ThemeManager
    let width: CGFloat
    let height: CGFloat
    
    // Constants for ruler styling
    private let barTickHeight: CGFloat = 6 // Shorter bar ticks
    private let barTickWidth: CGFloat = 1.0 // Width of bar ticks
    private let horizontalMarkerWidth: CGFloat = 1 // Width of horizontal marker at top of bar lines
    private let horizontalMarkerHeight: CGFloat = 1.0 // Height of horizontal marker
    private let dotRadius: CGFloat = 1.0 // Radius for beat dots
    private let midBarDotRadius: CGFloat = 1.5 // Radius for mid-bar dots when zoomed out
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Ruler background - solid color
            Rectangle()
                .fill(themeManager.tertiaryBackgroundColor)
                .frame(width: width, height: height)
            
            // Ticks, dots and bar numbers
            Canvas { context, size in
                // Calculate visible time range
                let pixelsPerBeat = state.effectivePixelsPerBeat
                let pixelsPerBar = pixelsPerBeat * Double(projectViewModel.timeSignatureBeats)
                
                // Number of divisions visible
                let visibleBars = 100 // Match the content width calculation
                
                // Get theme colors for drawing
                let textColor = themeManager.primaryTextColor.opacity(0.6) // Lighter text for bar numbers
                let barLineColor = themeManager.currentTheme == .light ? 
                    Color.black.opacity(0.5) : Color.white.opacity(0.5)
                let dotColor = themeManager.currentTheme == .light ? 
                    Color.black.opacity(0.3) : Color.white.opacity(0.3)
                
                // Determine if we're zoomed out (based on pixels per bar)
                let isZoomedOut = pixelsPerBar < 20 // Lower threshold for "zoomed out" state (was 40)
                
                // Draw bar ticks, horizontal markers, and numbers
                for barIndex in 0..<visibleBars {
                    let xPosition = CGFloat(Double(barIndex) * pixelsPerBar)
                    
                    // Determine if we should show this bar's line and number based on zoom level
                    let showBarLine = !isZoomedOut || barIndex % 4 == 0
                    let showBarNumber = state.shouldShowBarNumber(for: barIndex) && 
                                       (!isZoomedOut || (barIndex % 4 == 0))
                    
                    // Draw bar tick - shorter vertical line (only at appropriate intervals when zoomed out)
                    if showBarLine {
                        var barTickPath = Path()
                        barTickPath.move(to: CGPoint(x: xPosition, y: size.height))
                        barTickPath.addLine(to: CGPoint(x: xPosition, y: size.height - barTickHeight))
                        context.stroke(barTickPath, with: .color(barLineColor), lineWidth: barTickWidth)
                        
                        // Draw horizontal marker at the top of the bar tick
                        var horizontalMarkerPath = Path()
                        horizontalMarkerPath.move(to: CGPoint(x: xPosition, y: size.height - barTickHeight))
                        horizontalMarkerPath.addLine(to: CGPoint(x: xPosition + horizontalMarkerWidth, y: size.height - barTickHeight))
                        context.stroke(horizontalMarkerPath, with: .color(barLineColor), lineWidth: horizontalMarkerHeight)
                    }
                    // When zoomed out, draw dots at increments of 2 bars (if not already showing a line)
                    else if isZoomedOut && barIndex % 2 == 0 {
                        let dotRect = CGRect(
                            x: xPosition - midBarDotRadius,
                            y: size.height - midBarDotRadius * 2,
                            width: midBarDotRadius * 2,
                            height: midBarDotRadius * 2
                        )
                        var dotPath = Path(ellipseIn: dotRect)
                        context.fill(dotPath, with: .color(dotColor.opacity(0.7)))
                    }
                    
                    // Draw bar number (1-indexed) with lighter, smaller text
                    if showBarNumber {
                        let barText = Text("\(barIndex + 1)")
                            .font(.system(size: 9, weight: .light))
                            .foregroundColor(textColor)
                        context.draw(barText, at: CGPoint(x: xPosition + horizontalMarkerWidth + 2, y: size.height - barTickHeight - 4))
                    }
                    
                    // Draw beat dots within this bar (only if not zoomed out)
                    if !isZoomedOut && state.showQuarterNotes {
                        for beat in 1..<projectViewModel.timeSignatureBeats {
                            let beatX = xPosition + CGFloat(Double(beat) * pixelsPerBeat)
                            let dotRect = CGRect(
                                x: beatX - dotRadius,
                                y: size.height - dotRadius * 2,
                                width: dotRadius * 2,
                                height: dotRadius * 2
                            )
                            var dotPath = Path(ellipseIn: dotRect)
                            context.fill(dotPath, with: .color(dotColor))
                        }
                    }
                    
                    // Draw eighth note dots if zoom level permits
                    if !isZoomedOut && state.showEighthNotes {
                        for beat in 0..<(projectViewModel.timeSignatureBeats * 2) {
                            let eighthX = xPosition + CGFloat(Double(beat) * pixelsPerBeat / 2)
                            if eighthX.truncatingRemainder(dividingBy: CGFloat(pixelsPerBeat)) != 0 {
                                let dotRect = CGRect(
                                    x: eighthX - dotRadius * 0.8,
                                    y: size.height - dotRadius * 1.6,
                                    width: dotRadius * 1.6,
                                    height: dotRadius * 1.6
                                )
                                var dotPath = Path(ellipseIn: dotRect)
                                context.fill(dotPath, with: .color(dotColor.opacity(0.8)))
                            }
                        }
                    }
                    
                    // Draw sixteenth note dots if zoom level permits
                    if !isZoomedOut && state.showSixteenthNotes {
                        for beat in 0..<(projectViewModel.timeSignatureBeats * 4) {
                            let sixteenthX = xPosition + CGFloat(Double(beat) * pixelsPerBeat / 4)
                            if sixteenthX.truncatingRemainder(dividingBy: CGFloat(pixelsPerBeat / 2)) != 0 &&
                               sixteenthX.truncatingRemainder(dividingBy: CGFloat(pixelsPerBeat)) != 0 {
                                let dotRect = CGRect(
                                    x: sixteenthX - dotRadius * 0.6,
                                    y: size.height - dotRadius * 1.2,
                                    width: dotRadius * 1.2,
                                    height: dotRadius * 1.2
                                )
                                var dotPath = Path(ellipseIn: dotRect)
                                context.fill(dotPath, with: .color(dotColor.opacity(0.6)))
                            }
                        }
                    }
                }
            }
        }
        .frame(height: height)
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
        // .onHover { hovering in
        //     // Change cursor to indicate scrubbing is available
        //     if hovering {
        //         NSCursor.pointingHand.set()
        //     } else {
        //         NSCursor.arrow.set()
        //     }
        // }
    }
    
    // Snap a beat position to the nearest grid marker
    private func snapToNearestGridMarker(_ rawBeatPosition: Double) -> Double {
        // Determine the smallest visible grid division based on zoom level
        let gridDivision: Double
        let pixelsPerBar = state.effectivePixelsPerBeat * Double(projectViewModel.timeSignatureBeats)
        let isZoomedOut = pixelsPerBar < 20
        
        if state.showSixteenthNotes {
            // Snap to sixteenth notes (0.25 beat)
            gridDivision = 0.25
        } else if state.showEighthNotes {
            // Snap to eighth notes (0.5 beat)
            gridDivision = 0.5
        } else if state.showQuarterNotes {
            // Snap to quarter notes (1 beat)
            gridDivision = 1.0
        } else if isZoomedOut {
            // When zoomed out all the way, snap to 2-bar increments or 4-bar increments
            let beatsPerBar = Double(projectViewModel.timeSignatureBeats)
            
            // Calculate the nearest 2-bar and 4-bar positions
            let barPosition = rawBeatPosition / beatsPerBar
            let nearestTwoBarIndex = round(barPosition / 2.0) * 2.0
            let nearestFourBarIndex = round(barPosition / 4.0) * 4.0
            
            // Determine which is closer: the nearest 2-bar or 4-bar position
            let distanceToTwoBar = abs(barPosition - nearestTwoBarIndex)
            let distanceToFourBar = abs(barPosition - nearestFourBarIndex)
            
            let nearestBarIndex = distanceToTwoBar < distanceToFourBar ? nearestTwoBarIndex : nearestFourBarIndex
            return max(0, nearestBarIndex * beatsPerBar) // Ensure we don't go negative
        } else {
            // When zoomed out but not all the way, snap to bars
            let beatsPerBar = Double(projectViewModel.timeSignatureBeats)
            let barIndex = round(rawBeatPosition / beatsPerBar)
            return max(0, barIndex * beatsPerBar) // Ensure we don't go negative
        }
        
        // Calculate the nearest grid marker for beats and smaller divisions
        let nearestGridMarker = round(rawBeatPosition / gridDivision) * gridDivision
        
        return max(0, nearestGridMarker) // Ensure we don't go negative
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
