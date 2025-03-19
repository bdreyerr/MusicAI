import SwiftUI
import AppKit

/// Special view for the master track controls in the timeline
struct MasterTrackControlsView: View {
    let track: Track
    @ObservedObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    // State to track local changes before updating the model
    @State private var isMuted: Bool
    @State private var volume: Double
    
    // Initialize with track's current state
    init(track: Track, projectViewModel: ProjectViewModel) {
        self.track = track
        self.projectViewModel = projectViewModel
        
        // Initialize state from track
        _isMuted = State(initialValue: track.isMuted)
        _volume = State(initialValue: track.volume)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top row: Name and controls
            HStack(spacing: 6) {
                // Master icon and name
                HStack(spacing: 6) {
                    Image(systemName: track.type.icon)
                        .foregroundColor(themeManager.primaryTextColor)
                    
                    Text("Master")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(themeManager.primaryTextColor)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Mute button
                Button(action: {
                    isMuted.toggle()
                    updateTrackMuteState()
                }) {
                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2")
                        .foregroundColor(isMuted ? .red : themeManager.primaryTextColor)
                        .font(.system(size: 12))
                }
                .buttonStyle(BorderlessButtonStyle())
                .help("Mute Master Track")
                
                // Effects button
//                Button(action: {
//                    projectViewModel.selectTrack(id: track.id)
//                    // TODO: Show effects panel when implemented
//                }) {
//                    HStack(spacing: 4) {
//                        if !track.effects.isEmpty {
//                            Text("\(track.effects.count)")
//                                .font(.caption)
//                                .foregroundColor(themeManager.primaryTextColor)
//                        }
//                        Image(systemName: "slider.horizontal.3")
//                            .foregroundColor(themeManager.primaryTextColor)
//                            .font(.system(size: 12))
//                    }
//                }
//                .buttonStyle(BorderlessButtonStyle())
//                .help("Edit Effects")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            
            // Bottom row: Volume slider
            HStack(spacing: 8) {
                Image(systemName: "speaker.wave.1")
                    .foregroundColor(themeManager.primaryTextColor)
                    .font(.caption)
                
                Slider(value: $volume, in: 0...1) { editing in
                    if !editing {
                        updateTrackVolume()
                    }
                }
                .frame(height: 16)
                
                Text("\(Int(volume * 100))%")
                    .font(.caption)
                    .foregroundColor(themeManager.primaryTextColor)
                    .frame(width: 32, alignment: .trailing)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 4)
        }
        .frame(height: 50)
        .background(track.effectiveBackgroundColor(for: themeManager.currentTheme))
        .overlay(
            ZStack {
                Rectangle()
                    .stroke(themeManager.secondaryBorderColor, lineWidth: 0.5)
                    .allowsHitTesting(false)
                
                if projectViewModel.isTrackSelected(track) {
                    Rectangle()
                        .fill(themeManager.accentColor.opacity(0.15))
                        .brightness(0.1)
                        .allowsHitTesting(false)
                    
                    Rectangle()
                        .stroke(themeManager.accentColor.opacity(0.9), lineWidth: 1.5)
                        .brightness(0.3)
                        .allowsHitTesting(false)
                }
            }
        )
        .opacity(isMuted ? 0.7 : 1.0)
        .onTapGesture {
            projectViewModel.selectTrack(id: track.id)
        }
        .contentShape(Rectangle())
    }
    
    // MARK: - Helper Methods
    
    // Update track mute state
    private func updateTrackMuteState() {
        var updatedTrack = projectViewModel.masterTrack
        updatedTrack.isMuted = isMuted
        projectViewModel.masterTrack = updatedTrack
    }
    
    // Update track volume
    private func updateTrackVolume() {
        var updatedTrack = projectViewModel.masterTrack
        updatedTrack.volume = volume
        projectViewModel.masterTrack = updatedTrack
    }
}

#Preview {
    // Create a sample master track for the preview
    let masterTrack = Track(name: "Master", type: .master)
    return MasterTrackControlsView(
        track: masterTrack,
        projectViewModel: ProjectViewModel()
    )
    .environmentObject(ThemeManager())
} 
