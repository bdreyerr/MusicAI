import SwiftUI

/// A view that displays the current playback position with optimized update frequency
struct PositionDisplayView: View {
    @ObservedObject var projectViewModel: ProjectViewModel
    @State private var displayedPosition: String = "1.00"
    @State private var updateTimer: Timer? = nil
    @State private var lastUpdateTime: Date = Date()
    
    var body: some View {
        Text(displayedPosition)
            .font(.system(.subheadline, design: .monospaced))
            .foregroundColor(Color.primary)
            .onAppear {
                // Initialize with current position
                displayedPosition = projectViewModel.formattedPosition()
                
                // Start a timer that updates the display at a reduced rate
                startUpdateTimer()
            }
            .onDisappear {
                // Clean up timer when view disappears
                updateTimer?.invalidate()
                updateTimer = nil
            }
            .onChange(of: projectViewModel.isPlaying) { _, isPlaying in
                if isPlaying {
                    // When playback starts, use a slower update rate
                    startUpdateTimer()
                } else {
                    // When playback stops, update immediately and use a faster rate for scrubbing
                    displayedPosition = projectViewModel.formattedPosition()
                    startUpdateTimer(frequency: 10) // 10 Hz when not playing
                }
            }
    }
    
    private func startUpdateTimer(frequency: Double = 5) {
        // Cancel any existing timer
        updateTimer?.invalidate()
        
        // Create a new timer that updates at the specified frequency (default: 5 Hz)
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0/frequency, repeats: true) { _ in
            // Update the displayed position
            displayedPosition = projectViewModel.formattedPosition()
        }
    }
}

#Preview {
    PositionDisplayView(projectViewModel: ProjectViewModel())
} 