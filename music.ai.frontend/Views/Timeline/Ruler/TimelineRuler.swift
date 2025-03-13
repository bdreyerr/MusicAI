import SwiftUI

/// Ruler component that displays bar and beat markers at the top of the timeline
struct TimelineRuler: View {
    @ObservedObject var state: TimelineState
    @ObservedObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var themeManager: ThemeManager
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        ZStack {
            // Ruler background
            Rectangle()
                .fill(themeManager.tertiaryBackgroundColor)
                .frame(width: width, height: height)
            
            // Scrollable ruler content
            ScrollView(.horizontal, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    // Grid lines for bars and beats
                    Canvas { context, size in
                        // Calculate visible time range
                        let pixelsPerBeat = state.effectivePixelsPerBeat
                        let pixelsPerBar = pixelsPerBeat * Double(projectViewModel.timeSignatureBeats)
                        
                        // Number of divisions visible
                        let visibleBars = 100 // Match the content width calculation
                        
                        // Get theme colors for drawing
                        let darkBarColor = themeManager.currentTheme == .light ? 
                            Color.gray.opacity(0.25) : Color(white: 0.22)
                        let lightBarColor = themeManager.currentTheme == .light ? 
                            Color.gray.opacity(0.15) : Color(white: 0.27)
                        let majorLineColor = themeManager.currentTheme == .light ? 
                            Color.black.opacity(0.6) : Color.white.opacity(0.6)
                        let minorLineColor = themeManager.currentTheme == .light ? 
                            Color.gray.opacity(0.3) : Color.gray.opacity(0.4)
                        let textColor = themeManager.primaryTextColor
                        let emphasisTextColor = themeManager.currentTheme == .light ? 
                            Color.black : Color.white
                        
                        // Draw bar lines and numbers
                        for barIndex in 0..<visibleBars {
                            let xPosition = CGFloat(Double(barIndex) * pixelsPerBar)
                            
                            // Draw alternating bar backgrounds
                            var barRect = Path(CGRect(x: xPosition, y: 0, width: CGFloat(pixelsPerBar), height: height))
                            context.fill(barRect, with: .color(barIndex % 2 == 0 ? lightBarColor : darkBarColor))
                            
                            // Draw bar line
                            var barPath = Path()
                            barPath.move(to: CGPoint(x: xPosition, y: 0))
                            barPath.addLine(to: CGPoint(x: xPosition, y: height))
                            
                            // Determine if this is a major bar (multiple of 4)
                            let isMajorBar = barIndex > 0 && barIndex % 4 == 0
                            context.stroke(barPath, with: .color(isMajorBar ? majorLineColor : minorLineColor), 
                                          lineWidth: isMajorBar ? 1.5 : 1.0)
                            
                            // Draw bar number (1-indexed)
                            let barText = Text("\(barIndex + 1)")
                                .font(.system(size: 11, weight: isMajorBar ? .bold : .medium))
                                .foregroundColor(isMajorBar ? emphasisTextColor : textColor)
                            context.draw(barText, at: CGPoint(x: xPosition + 5, y: 5))
                            
                            // Draw beat lines within this bar
                            if state.showQuarterNotes {
                                for beat in 1..<projectViewModel.timeSignatureBeats {
                                    let beatX = xPosition + CGFloat(Double(beat) * pixelsPerBeat)
                                    var beatPath = Path()
                                    beatPath.move(to: CGPoint(x: beatX, y: 0))
                                    beatPath.addLine(to: CGPoint(x: beatX, y: height))
                                    context.stroke(beatPath, with: .color(minorLineColor), lineWidth: 0.5)
                                }
                            }
                            
                            // Draw eighth notes if zoom level permits
                            if state.showEighthNotes {
                                for beat in 0..<(projectViewModel.timeSignatureBeats * 2) {
                                    let eighthX = xPosition + CGFloat(Double(beat) * pixelsPerBeat / 2)
                                    if eighthX.truncatingRemainder(dividingBy: CGFloat(pixelsPerBeat)) != 0 {
                                        var eighthPath = Path()
                                        eighthPath.move(to: CGPoint(x: eighthX, y: height / 2))
                                        eighthPath.addLine(to: CGPoint(x: eighthX, y: height))
                                        context.stroke(eighthPath, with: .color(themeManager.tertiaryGridColor), lineWidth: 0.5)
                                    }
                                }
                            }
                            
                            // Draw sixteenth notes if zoom level permits
                            if state.showSixteenthNotes {
                                for beat in 0..<(projectViewModel.timeSignatureBeats * 4) {
                                    let sixteenthX = xPosition + CGFloat(Double(beat) * pixelsPerBeat / 4)
                                    if sixteenthX.truncatingRemainder(dividingBy: CGFloat(pixelsPerBeat / 2)) != 0 &&
                                       sixteenthX.truncatingRemainder(dividingBy: CGFloat(pixelsPerBeat)) != 0 {
                                        var sixteenthPath = Path()
                                        sixteenthPath.move(to: CGPoint(x: sixteenthX, y: height * 0.75))
                                        sixteenthPath.addLine(to: CGPoint(x: sixteenthX, y: height))
                                        context.stroke(sixteenthPath, with: .color(themeManager.tertiaryGridColor), lineWidth: 0.5)
                                    }
                                }
                            }
                        }
                    }
                    .frame(width: CGFloat(100 * projectViewModel.timeSignatureBeats) * state.effectivePixelsPerBeat)
                    
                    // Playhead indicator for ruler
                    PlayheadIndicator(
                        currentBeat: projectViewModel.currentBeat,
                        state: state
                    )
                    .environmentObject(themeManager)
                }
            }
            
            // Current position display (fixed overlay)
            HStack {
                Text(projectViewModel.formattedPosition())
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme == .dark ? Color.black : Color.black)
                    .padding(.horizontal, 8)
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(4)
                
                Spacer()
                
                // Zoom level indicator
                Text(String(format: "Zoom: %.1fx", state.zoomLevel))
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme == .dark ? Color.black : Color.black)
                    .padding(.horizontal, 8)
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(4)
            }
            .padding(.horizontal, 8)
            .zIndex(10)
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