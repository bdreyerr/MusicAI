import SwiftUI

// MARK: - Volume Slider View

struct VolumeSliderView: View {
    @ObservedObject var trackViewModel: TrackViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "speaker.wave.1")
                .foregroundColor(themeManager.primaryTextColor)
                .font(.caption)
            
            Slider(value: $trackViewModel.volume, in: 0...1) { editing in
                if !editing {
                    trackViewModel.updateTrackVolume()
                }
            }
            .frame(height: 16)
            
            Text("\(Int(trackViewModel.volume * 100))%")
                .font(.caption)
                .foregroundColor(themeManager.primaryTextColor)
                .frame(width: 32, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
    }
} 