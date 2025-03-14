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
                // Add a subtle highlight when the track is selected
                .overlay(
                    Rectangle()
                        .stroke(Color.white, lineWidth: projectViewModel.isTrackSelected(track) ? 2 : 0)
                        .opacity(projectViewModel.isTrackSelected(track) ? 0.5 : 0)
                )
                .zIndex(0) // Background at the bottom
            
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
            .zIndex(1) // Grid lines above background
            
            // Add the selection visualization
            TimelineSelectionView(
                state: state,
                track: track,
                projectViewModel: projectViewModel
            )
            .environmentObject(themeManager)
            .zIndex(2) // Selection above grid but below clips
            .allowsHitTesting(false) // Don't block clicks
            
            // Display placeholder text or MIDI clips based on track type
            if track.type == .midi {
                // Show placeholder text if no clips
                if track.midiClips.isEmpty {
                    Text("Right-click to create MIDI clip")
                        .font(.caption)
                        .foregroundColor(themeManager.secondaryTextColor)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .zIndex(3) // Above selection but below clips
                        .allowsHitTesting(false) // Don't block clicks
                }
                
                // Display MIDI clips if this is a MIDI track
                ForEach(track.midiClips) { clip in
                    MidiClipView(
                        clip: clip,
                        track: track,
                        state: state,
                        projectViewModel: projectViewModel
                    )
                    .environmentObject(themeManager)
                    .zIndex(10) // Ensure clips are above other elements for better interaction
                }
            } else {
                // Placeholder for audio tracks
                Text("Drop audio clips here")
                    .font(.caption)
                    .foregroundColor(themeManager.secondaryTextColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .zIndex(3) // Above selection
                    .allowsHitTesting(false) // Don't block clicks
            }
            
            // Add the selector overlay for click/drag interactions
            TimelineSelector(
                projectViewModel: projectViewModel,
                state: state,
                track: track
            )
            .zIndex(20) // Highest z-index to capture all clicks
            .allowsHitTesting(true) // Ensure the selector can receive clicks
        }
        .frame(width: width, height: track.height) // Use track's height property
        .overlay(
            // Enhanced selection indicator
            ZStack {
                // Regular border for all tracks
                Rectangle()
                    .stroke(themeManager.secondaryBorderColor, lineWidth: 0.5)
                    .allowsHitTesting(false)
                
                // Special border for selected track - using a brighter version of the track's color
                if projectViewModel.isTrackSelected(track) {
                    Rectangle()
                        .stroke(track.effectiveColor.opacity(0.9), lineWidth: 1.5)
                        .brightness(0.3) // Make the color brighter for better visibility
                        .allowsHitTesting(false)
                }
            }
        )
        .opacity((!track.isEnabled || isMuted) && !isSolo ? 0.5 : 1.0) // Dim the track if disabled or muted (unless soloed)
        // Add context menu for track operations
        .contextMenu {
            // Create MIDI clip option (only for MIDI tracks and when there's a selection)
            if track.type == .midi && state.hasSelection(trackId: track.id) {
                Button("Create MIDI Clip") {
                    projectViewModel.createMidiClipFromSelection()
                }
                
                Divider()
            }
            
            // Track operations
            Button("Rename Track") {
                // Rename functionality would be handled in TrackControlsView
            }
            
            Button("Delete Track") {
                if let index = projectViewModel.tracks.firstIndex(where: { $0.id == track.id }) {
                    projectViewModel.removeTrack(at: index)
                }
            }
            
            if track.type == .midi {
                Divider()
                
                Button("Add Instrument") {
                    // Add instrument functionality would go here
                }
            }
        }
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