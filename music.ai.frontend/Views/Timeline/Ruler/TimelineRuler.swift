import SwiftUI

/// Ruler component that displays bar and beat markers at the top of the timeline
struct TimelineRuler: View {
    @ObservedObject var state: TimelineState
    @ObservedObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var themeManager: ThemeManager
    let width: CGFloat
    let height: CGFloat
    
    // Constants for uptick heights
    private let barTickHeight: CGFloat = 12
    private let beatTickHeight: CGFloat = 8
    private let eighthTickHeight: CGFloat = 5
    private let sixteenthTickHeight: CGFloat = 3
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Ruler background - solid color
            Rectangle()
                .fill(themeManager.tertiaryBackgroundColor)
                .frame(width: width, height: height)
            
            // Ticks and bar numbers
            Canvas { context, size in
                // Calculate visible time range
                let pixelsPerBeat = state.effectivePixelsPerBeat
                let pixelsPerBar = pixelsPerBeat * Double(projectViewModel.timeSignatureBeats)
                
                // Number of divisions visible
                let visibleBars = 100 // Match the content width calculation
                
                // Get theme colors for drawing
                let textColor = themeManager.primaryTextColor
                let emphasisTextColor = themeManager.currentTheme == .light ? 
                    Color.black : Color.white
                let majorTickColor = themeManager.currentTheme == .light ? 
                    Color.black.opacity(0.8) : Color.white.opacity(0.8)
                let minorTickColor = themeManager.currentTheme == .light ? 
                    Color.black.opacity(0.6) : Color.white.opacity(0.6)
                let beatTickColor = themeManager.currentTheme == .light ? 
                    Color.black.opacity(0.5) : Color.white.opacity(0.5)
                let smallTickColor = themeManager.currentTheme == .light ? 
                    Color.black.opacity(0.3) : Color.white.opacity(0.3)
                
                // Draw bar ticks and numbers
                for barIndex in 0..<visibleBars {
                    let xPosition = CGFloat(Double(barIndex) * pixelsPerBar)
                    
                    // Determine if this is a major bar (multiple of 4)
                    let isMajorBar = barIndex > 0 && barIndex % 4 == 0
                    
                    // Draw bar tick at the bottom of the ruler
                    var barTickPath = Path()
                    barTickPath.move(to: CGPoint(x: xPosition, y: size.height))
                    barTickPath.addLine(to: CGPoint(x: xPosition, y: size.height - barTickHeight))
                    context.stroke(barTickPath, with: .color(isMajorBar ? majorTickColor : minorTickColor), 
                                  lineWidth: isMajorBar ? 1.5 : 1.0)
                    
                    // Draw bar number (1-indexed) only if it should be shown at current zoom level
                    if state.shouldShowBarNumber(for: barIndex) {
                        let barText = Text("\(barIndex + 1)")
                            .font(.system(size: 11, weight: isMajorBar ? .bold : .medium))
                            .foregroundColor(isMajorBar ? emphasisTextColor : textColor)
                        context.draw(barText, at: CGPoint(x: xPosition + 5, y: 5))
                    }
                    
                    // Draw beat ticks within this bar
                    if state.showQuarterNotes {
                        for beat in 1..<projectViewModel.timeSignatureBeats {
                            let beatX = xPosition + CGFloat(Double(beat) * pixelsPerBeat)
                            var beatTickPath = Path()
                            beatTickPath.move(to: CGPoint(x: beatX, y: size.height))
                            beatTickPath.addLine(to: CGPoint(x: beatX, y: size.height - beatTickHeight))
                            context.stroke(beatTickPath, with: .color(beatTickColor), lineWidth: 1.0)
                        }
                    }
                    
                    // Draw eighth note ticks if zoom level permits
                    if state.showEighthNotes {
                        for beat in 0..<(projectViewModel.timeSignatureBeats * 2) {
                            let eighthX = xPosition + CGFloat(Double(beat) * pixelsPerBeat / 2)
                            if eighthX.truncatingRemainder(dividingBy: CGFloat(pixelsPerBeat)) != 0 {
                                var eighthTickPath = Path()
                                eighthTickPath.move(to: CGPoint(x: eighthX, y: size.height))
                                eighthTickPath.addLine(to: CGPoint(x: eighthX, y: size.height - eighthTickHeight))
                                context.stroke(eighthTickPath, with: .color(smallTickColor), lineWidth: 0.5)
                            }
                        }
                    }
                    
                    // Draw sixteenth note ticks if zoom level permits
                    if state.showSixteenthNotes {
                        for beat in 0..<(projectViewModel.timeSignatureBeats * 4) {
                            let sixteenthX = xPosition + CGFloat(Double(beat) * pixelsPerBeat / 4)
                            if sixteenthX.truncatingRemainder(dividingBy: CGFloat(pixelsPerBeat / 2)) != 0 &&
                               sixteenthX.truncatingRemainder(dividingBy: CGFloat(pixelsPerBeat)) != 0 {
                                var sixteenthTickPath = Path()
                                sixteenthTickPath.move(to: CGPoint(x: sixteenthX, y: size.height))
                                sixteenthTickPath.addLine(to: CGPoint(x: sixteenthX, y: size.height - sixteenthTickHeight))
                                context.stroke(sixteenthTickPath, with: .color(smallTickColor), lineWidth: 0.5)
                            }
                        }
                    }
                }
            }
            
            // Playhead indicator for ruler
            PlayheadIndicator(
                currentBeat: projectViewModel.currentBeat,
                state: state
            )
            .environmentObject(themeManager)
        }
        .frame(height: height)
    }
}

#Preview {
    TimelineRuler(
        state: TimelineState(),
        projectViewModel: ProjectViewModel(),
        width: 800,
        height: 40
    )
    .environmentObject(ThemeManager())
} 