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
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.8))
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                )
                .foregroundColor(.white)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isVisible)
        .onChange(of: projectViewModel.currentBeat) { _, newBeat in
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
        
        // Use the gridDivision property to determine what to display
        switch state.gridDivision {
        case .sixteenth:
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
            
        case .eighth:
            // Show eighth note precision
            if beatFraction == 0.0 {
                return "Beat"
            } else if beatFraction == 0.5 {
                return "8th Note"
            }
            
        case .quarter:
            // Show quarter note precision
            return "Beat"
            
        case .half:
            // Show half-bar precision
            if Int(beat * 2) % 2 == 0 {
                return "Bar"
            } else {
                return "Half-Bar"
            }
            
        case .bar, .twoBar, .fourBar:
            // Show bar precision
            return "Bar"
        }
        
        return "Beat"
    }
}

#Preview {
    ScrubPositionIndicator(
        projectViewModel: ProjectViewModel(),
        state: TimelineStateViewModel()
    )
} 
