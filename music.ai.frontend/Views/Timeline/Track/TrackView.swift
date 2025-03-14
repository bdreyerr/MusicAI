import SwiftUI

/// View for an individual track in the timeline
struct TrackView: View {
    let track: Track
    @ObservedObject var state: TimelineState
    @ObservedObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var themeManager: ThemeManager
    let width: CGFloat
    
    // State to track local changes before updating the model
    @State private var isMuted: Bool
    @State private var isSolo: Bool
    @State private var isArmed: Bool
    
    // Initialize with track's current state
    init(track: Track, state: TimelineState, projectViewModel: ProjectViewModel, width: CGFloat) {
        self.track = track
        self.state = state
        self.projectViewModel = projectViewModel
        self.width = width
        
        // Initialize state from track
        _isMuted = State(initialValue: track.isMuted)
        _isSolo = State(initialValue: track.isSolo)
        _isArmed = State(initialValue: track.isArmed)
    }
    
    var body: some View {
        // Track content section (scrollable) - fill the entire height
        ZStack(alignment: .topLeading) {
            // Background with track type color
            Rectangle()
                .fill(track.effectiveBackgroundColor(for: themeManager.currentTheme))
            
            // Beat/bar divisions
            Canvas { context, size in
                // Calculate grid dimensions
                let pixelsPerBeat = state.effectivePixelsPerBeat
                let pixelsPerBar = pixelsPerBeat * Double(projectViewModel.timeSignatureBeats)
                
                // Number of bars visible
                let visibleBars = 100 // Match the content width calculation
                
                // Vertical grid lines (time divisions)
                for barIndex in 0..<visibleBars {
                    let xPosition = CGFloat(Double(barIndex) * pixelsPerBar)
                    
                    // Bar lines (strong)
                    var barPath = Path()
                    barPath.move(to: CGPoint(x: xPosition, y: 0))
                    barPath.addLine(to: CGPoint(x: xPosition, y: size.height))
                    context.stroke(barPath, with: .color(themeManager.gridColor), lineWidth: 1.0)
                    
                    // Beat lines (medium)
                    if state.showQuarterNotes {
                        for beat in 1..<projectViewModel.timeSignatureBeats {
                            let beatX = xPosition + CGFloat(Double(beat) * pixelsPerBeat)
                            var beatPath = Path()
                            beatPath.move(to: CGPoint(x: beatX, y: 0))
                            beatPath.addLine(to: CGPoint(x: beatX, y: size.height))
                            context.stroke(beatPath, with: .color(themeManager.secondaryGridColor), lineWidth: 0.5)
                        }
                    }
                    
                    // Eighth notes (weak)
                    if state.showEighthNotes {
                        for beat in 0..<(projectViewModel.timeSignatureBeats * 2) {
                            let eighthX = xPosition + CGFloat(Double(beat) * pixelsPerBeat / 2)
                            if eighthX.truncatingRemainder(dividingBy: CGFloat(pixelsPerBeat)) != 0 {
                                var eighthPath = Path()
                                eighthPath.move(to: CGPoint(x: eighthX, y: 0))
                                eighthPath.addLine(to: CGPoint(x: eighthX, y: size.height))
                                context.stroke(eighthPath, with: .color(themeManager.tertiaryGridColor), lineWidth: 0.5)
                            }
                        }
                    }
                }
            }
            
            // Placeholder for clips (in a real app, we would render clips here)
            Text("Drop audio clips here")
                .font(.caption)
                .foregroundColor(themeManager.secondaryTextColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: width, height: track.height) // Use track's height property
        .overlay(
            Rectangle()
                .stroke(themeManager.secondaryBorderColor, lineWidth: 0.5)
                .allowsHitTesting(false)
        )
        .opacity((!track.isEnabled || isMuted) && !isSolo ? 0.5 : 1.0) // Dim the track if disabled or muted (unless soloed)
    }
    
    // Update the track in the project view model
    private func updateTrack() {
        // Find the track in the view model's tracks array
        if let index = projectViewModel.tracks.firstIndex(where: { $0.id == track.id }) {
            // Create an updated track with the new state
            var updatedTrack = track
            updatedTrack.isMuted = isMuted
            updatedTrack.isSolo = isSolo
            updatedTrack.isArmed = isArmed
            
            // Update the track in the view model
            projectViewModel.updateTrack(at: index, with: updatedTrack)
        }
    }
}

#Preview {
    TrackView(
        track: Track.samples[0],
        state: TimelineState(),
        projectViewModel: ProjectViewModel(),
        width: 800
    )
    .environmentObject(ThemeManager())
} 