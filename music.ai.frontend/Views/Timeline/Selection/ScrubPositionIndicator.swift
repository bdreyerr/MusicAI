import SwiftUI

/// ScrubPositionIndicator displays the current position (bar.beat) when scrubbing
struct ScrubPositionIndicator: View {
    @ObservedObject var projectViewModel: ProjectViewModel
    @ObservedObject var state: TimelineStateViewModel
    @State private var isVisible: Bool = false
    @State private var lastUpdateTime: Date = Date()
    @State private var displayedPosition: String = ""
    @State private var displayedDivision: String = ""
    
    var body: some View {
        VStack {
            // Only show when scrubbing or briefly after, and NOT during playback
            if isVisible && !projectViewModel.isPlaying {
                VStack(spacing: 4) {
                    // Show the bar.beat position
                    Text(displayedPosition)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                    
                    // Show the note division based on zoom level
                    Text(displayedDivision)
                        .font(.system(size: 12, design: .monospaced))
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.black.opacity(0.7))
                )
                .foregroundColor(.white)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isVisible)
        .onChange(of: projectViewModel.currentBeat) { _ in
            // Only show and update when not playing
            if !projectViewModel.isPlaying {
                // Update the displayed text (only when visible to avoid unnecessary calculations)
                if !isVisible || Date().timeIntervalSince(lastUpdateTime) >= 0.1 {
                    displayedPosition = projectViewModel.formattedPosition()
                    displayedDivision = noteDivisionText()
                }
                
                // Show the indicator when the position changes
                isVisible = true
                lastUpdateTime = Date()
                
                // Hide after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    // Only hide if this was the last update
                    if Date().timeIntervalSince(lastUpdateTime) >= 1.5 {
                        isVisible = false
                    }
                }
            } else {
                // Hide immediately during playback
                isVisible = false
            }
        }
    }
    
    /// Returns a text description of the current note division based on zoom level
    private func noteDivisionText() -> String {
        let beat = projectViewModel.currentBeat
        let beatFraction = beat.truncatingRemainder(dividingBy: 1.0)
        
        if state.showSixteenthNotes {
            // Show sixteenth note precision
            if beatFraction == 0.0 {
                return "Beat"
            } else if beatFraction == 0.25 {
                return "16th Note"
            } else if beatFraction == 0.5 {
                return "8th Note"
            } else if beatFraction == 0.75 {
                return "16th Note"
            }
        } else if state.showEighthNotes {
            // Show eighth note precision
            if beatFraction == 0.0 {
                return "Beat"
            } else if beatFraction == 0.5 {
                return "8th Note"
            }
        } else if state.showQuarterNotes {
            // Show quarter note precision
            return "Beat"
        } else {
            // Show bar precision
            return "Bar"
        }
        
        return ""
    }
}

#Preview {
    ScrubPositionIndicator(
        projectViewModel: ProjectViewModel(),
        state: TimelineStateViewModel()
    )
} 
