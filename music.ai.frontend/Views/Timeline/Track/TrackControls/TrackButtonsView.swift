import SwiftUI

// MARK: - Track Control Buttons View

struct TrackButtonsView: View {
    let track: Track
    @ObservedObject var trackViewModel: TrackViewModel
    @EnvironmentObject var themeManager: ThemeManager
    var onDelete: () -> Void
    
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                // Mute button
                Button(action: {
                    trackViewModel.toggleMute()
                }) {
                    Image(systemName: trackViewModel.isMuted ? "speaker.slash.fill" : "speaker.wave.2")
                        .foregroundColor(trackViewModel.isMuted ? .red : themeManager.primaryTextColor)
                        .font(.system(size: 12))
                }
                .buttonStyle(BorderlessButtonStyle())
                .help("Mute Track")
                
                // Record arm button
                Button(action: {
                    trackViewModel.toggleArmed()
                }) {
                    Image(systemName: "record.circle")
                        .font(.system(size: 12))
                        .foregroundColor(trackViewModel.isArmed ? .red : themeManager.primaryTextColor)
                }
                .buttonStyle(BorderlessButtonStyle())
                .help("Arm Track for Recording")
                
                // Pan control with more space now that buttons are moved
                PanSliderView(trackViewModel: trackViewModel)
                    .environmentObject(themeManager)
                
                // Delete track button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(themeManager.primaryTextColor)
                }
                .buttonStyle(BorderlessButtonStyle())
                .help("Delete Track")
            }
            .padding(.trailing, 8)
            
            Spacer()
        }
        .padding(.leading, 8)
        .padding(.bottom, 1)
    }
}

// MARK: - Pan Slider View

struct PanSliderView: View {
    @ObservedObject var trackViewModel: TrackViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 4) {
            Text("L")
                .font(.caption2)
                .foregroundColor(themeManager.primaryTextColor)
            
            Slider(value: $trackViewModel.pan, in: 0...1) { editing in
                if !editing {
                    trackViewModel.updateTrackPan()
                }
            }
            .accentColor(trackViewModel.effectiveColor)
            .frame(width: 80, height: 16) // Increased width from 50 to 100
            
            Text("R")
                .font(.caption2)
                .foregroundColor(themeManager.primaryTextColor)
        }
    }
} 
