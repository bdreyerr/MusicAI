import SwiftUI

/// View for the controls section of a track in the timeline
struct TrackControlsView: View {
    let track: Track
    @ObservedObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    // State to track local changes before updating the model
    @State private var isMuted: Bool
    @State private var isSolo: Bool
    @State private var isArmed: Bool
    
    // Initialize with track's current state
    init(track: Track, projectViewModel: ProjectViewModel) {
        self.track = track
        self.projectViewModel = projectViewModel
        
        // Initialize state from track
        _isMuted = State(initialValue: track.isMuted)
        _isSolo = State(initialValue: track.isSolo)
        _isArmed = State(initialValue: track.isArmed)
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Background
            Rectangle()
                .fill(themeManager.secondaryBackgroundColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Track controls row - aligned at the top
            HStack {
                // Track icon and name
                HStack(spacing: 6) {
                    Image(systemName: track.type.icon)
                        .foregroundColor(track.type.color)
                    
                    Text(track.name)
                        .font(.subheadline)
                        .foregroundColor(themeManager.primaryTextColor)
                        .lineLimit(1)
                }
                .padding(.leading, 8)
                
                Spacer()
                
                // Track controls
                HStack(spacing: 8) {
                    // Mute button
                    Button(action: {
                        isMuted.toggle()
                        updateTrack()
                    }) {
                        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2")
                            .foregroundColor(isMuted ? .red : themeManager.primaryTextColor)
                            .font(.caption)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .help("Mute Track")
                    
                    // Solo button
                    Button(action: {
                        isSolo.toggle()
                        updateTrack()
                    }) {
                        Text("S")
                            .font(.caption)
                            .padding(3)
                            .background(isSolo ? Color.yellow : Color.clear)
                            .foregroundColor(isSolo ? .black : themeManager.primaryTextColor)
                            .cornerRadius(3)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .help("Solo Track")
                    
                    // Record arm button
                    Button(action: {
                        isArmed.toggle()
                        updateTrack()
                    }) {
                        Image(systemName: "record.circle")
                            .font(.caption)
                            .foregroundColor(isArmed ? .red : themeManager.secondaryTextColor)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .help("Arm Track for Recording")
                }
                .padding(.trailing, 8)
            }
            .frame(height: 40)
            .frame(maxWidth: .infinity)
        }
        .overlay(
            Rectangle()
                .stroke(themeManager.secondaryBorderColor, lineWidth: 0.5)
                .allowsHitTesting(false)
        )
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
    TrackControlsView(
        track: Track.samples[0],
        projectViewModel: ProjectViewModel()
    )
    .environmentObject(ThemeManager())
    .frame(width: 200, height: 70) // Match the height used in TimelineView
} 