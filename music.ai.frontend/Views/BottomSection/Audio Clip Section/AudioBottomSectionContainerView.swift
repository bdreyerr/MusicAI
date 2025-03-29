//
//  AudioBottomSectionContainerView.swift
//  music.ai.frontend
//
//  Created by Ben Dreyer on 3/28/25.
//

import SwiftUI

struct AudioBottomSectionContainerView: View {
    let track: Track
    @ObservedObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    // Computed property to get the selected clip
    private var selectedClip: AudioClip? {
        guard let timelineState = projectViewModel.timelineState,
              timelineState.selectionActive,
              projectViewModel.selectedTrackId == track.id else {
            return nil
        }
        
        // Get the selection range
        let (selStart, selEnd) = timelineState.normalizedSelectionRange
        
        // Find the clip that matches the selection range
        return track.audioClips.first { clip in
            abs(clip.startPositionInBeats - selStart) < 0.001 &&
            abs(clip.endBeat - selEnd) < 0.001
        }
    }
    
    var body: some View {
        if projectViewModel.audioViewModel.isAudioClipSelected(trackId: track.id),
           let clip = selectedClip {
            HStack(spacing: 0) {
                // Left side: Audio clip controls and information
                AudioBottomSectionControlsView(clip: clip)
                
                // Divider
                Rectangle()
                    .fill(themeManager.secondaryBorderColor)
                    .frame(width: 1)
                
                // Right side: Waveform visualization
                AudioBottomSectionWaveformView(clip: clip, projectViewModel: projectViewModel)
                    .frame(maxWidth: .infinity)
            }
            .background(themeManager.secondaryBackgroundColor)
        } else {
            // No clip selected
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "waveform")
                            .font(.system(size: 32))
                            .foregroundColor(themeManager.secondaryTextColor)
                        Text("No Clip Selected")
                            .font(.headline)
                            .foregroundColor(themeManager.secondaryTextColor)
                        Text("Select an audio clip to view the waveform")
                            .font(.caption)
                            .foregroundColor(themeManager.secondaryTextColor.opacity(0.8))
                    }
                    Spacer()
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(themeManager.secondaryBackgroundColor)
        }
    }
}

// Preview
#Preview {
    // Create a test track with a sample audio clip
    let track = Track(id: UUID(), name: "Audio Track", type: .audio)
    let projectViewModel = ProjectViewModel()
    
    return AudioBottomSectionContainerView(track: track, projectViewModel: projectViewModel)
        .environmentObject(ThemeManager())
}
