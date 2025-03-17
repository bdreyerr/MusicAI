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
        Canvas { context, size in
            // Calculate grid dimensions
            let pixelsPerBeat = state.effectivePixelsPerBeat
            let pixelsPerBar = pixelsPerBeat * Double(projectViewModel.timeSignatureBeats)
            
            // Calculate visible range based on scroll offset
            let scrollX = state.scrollOffset.x
            let startX = scrollX
            let endX = startX + size.width
            
            // Calculate the visible bar range
            let startBar = max(0, Int(floor(startX / CGFloat(pixelsPerBar))))
            
            // Calculate the maximum bar index based on content width
            let maxBarIndex = Int(ceil(width / CGFloat(pixelsPerBar)))
            let endBar = min(maxBarIndex, Int(ceil(endX / CGFloat(pixelsPerBar))) + 1)
            
            // Determine if we're zoomed out (based on pixels per bar)
            let isZoomedOut = pixelsPerBar < 40
            let isVeryZoomedOut = pixelsPerBar < 20
            let isExtremelyZoomedOut = pixelsPerBar < 10
            
            // Minimum pixel distance between bar numbers to prevent overcrowding
            let minPixelsBetweenBarNumbers: CGFloat = 60
            
            // Use simplified rendering during playback
            let useSimplifiedRendering = projectViewModel.isPlaying
            
            // Skip factor for rendering based on zoom level and playback state
            let skipFactor = isExtremelyZoomedOut ? 8 : (isVeryZoomedOut ? 4 : (isZoomedOut ? 2 : 1))
            
            // Minimum pixel distance between grid lines to prevent overcrowding
            let minPixelsBetweenLines: CGFloat = 15
            
            // Draw bar lines and numbers
            for barIndex in stride(from: startBar, to: endBar, by: skipFactor) {
                let xPosition = CGFloat(Double(barIndex) * pixelsPerBar)
                
                // Skip if the bar is outside the viewport
                if xPosition + CGFloat(pixelsPerBar) < scrollX || xPosition > scrollX + size.width {
                    continue
                }
                
                // Determine if we should show this bar's line and number based on zoom level
                let showBarLine: Bool
                if isExtremelyZoomedOut {
                    showBarLine = barIndex % 2 == 0
                } else if isVeryZoomedOut {
                    showBarLine = barIndex % 4 == 0
                } else if isZoomedOut {
                    showBarLine = barIndex % 2 == 0
                } else {
                    showBarLine = true
                }
                
                // Determine if we should show the bar number
                let showBarNumber = showBarLine && 
                                   (pixelsPerBar >= minPixelsBetweenBarNumbers || barIndex % 4 == 0) &&
                                   state.shouldShowBarNumber(for: barIndex)
                
                // Draw bar tick - shorter vertical line (only at appropriate intervals when zoomed out)
                if showBarLine {
                    var path = Path()
                    path.move(to: CGPoint(x: xPosition, y: size.height - 8))
                    path.addLine(to: CGPoint(x: xPosition, y: size.height))
                    
                    context.stroke(
                        path,
                        with: .color(themeManager.primaryTextColor),
                        lineWidth: 1.0
                    )
                }
                
                // Draw bar number (only at appropriate intervals)
                if showBarNumber {
                    let text = Text("\(barIndex + 1)")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(themeManager.primaryTextColor)
                    
                    context.draw(text, at: CGPoint(x: xPosition + 4, y: 4))
                }
                
                // Only draw beat ticks if we're not extremely zoomed out and have enough space between lines
                if !isExtremelyZoomedOut && pixelsPerBeat >= minPixelsBetweenLines {
                    // Draw beat ticks
                    for beat in 1..<projectViewModel.timeSignatureBeats {
                        let beatX = xPosition + CGFloat(Double(beat) * pixelsPerBeat)
                        
                        // Skip if the beat is outside the viewport
                        if beatX < scrollX || beatX > scrollX + size.width {
                            continue
                        }
                        
                        // Draw beat tick - shorter than bar ticks
                        var beatPath = Path()
                        beatPath.move(to: CGPoint(x: beatX, y: size.height - 5))
                        beatPath.addLine(to: CGPoint(x: beatX, y: size.height))
                        
                        context.stroke(
                            beatPath,
                            with: .color(themeManager.secondaryTextColor),
                            lineWidth: 0.5
                        )
                    }
                }
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
        } else if state.showHalfNotes {
            // Snap to half notes (2 beats)
            gridDivision = 2.0
        } else if isZoomedOut {
            // When zoomed out all the way, snap to 2-bar increments
            let beatsPerBar = Double(projectViewModel.timeSignatureBeats)
            
            // Calculate the nearest 2-bar position
            let barPosition = rawBeatPosition / beatsPerBar
            let nearestTwoBarIndex = round(barPosition / 2.0) * 2.0
            
            return max(0, nearestTwoBarIndex * beatsPerBar) // Ensure we don't go negative
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
