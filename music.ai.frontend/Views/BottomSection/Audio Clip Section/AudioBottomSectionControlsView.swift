//
//  AudioBottomSectionControlsView.swift
//  music.ai.frontend
//
//  Created by Ben Dreyer on 3/28/25.
//

import SwiftUI

struct AudioBottomSectionControlsView: View {
    let clip: AudioClip
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Clip name header
            Text(clip.name)
                .font(.headline)
                .foregroundColor(themeManager.primaryTextColor)
                .padding(.bottom, 2)
            
            // Duration information
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("Duration:")
                        .font(.subheadline)
                        .foregroundColor(themeManager.secondaryTextColor)
                    
                    Text(String(format: "%.2f beats", clip.durationInBeats))
                        .font(.subheadline)
                        .foregroundColor(themeManager.primaryTextColor)
                }
                
                HStack(spacing: 4) {
                    Text("Time:")
                        .font(.subheadline)
                        .foregroundColor(themeManager.secondaryTextColor)
                    
                    // Calculate seconds from audio window duration
                    Text(formatTime(seconds: clip.audioWindowDuration))
                        .font(.subheadline)
                        .foregroundColor(themeManager.primaryTextColor)
                }
            }
            
            // Audio file information
            Text("From: \(clip.audioItem.name)")
                .font(.caption)
                .foregroundColor(themeManager.secondaryTextColor)
                .padding(.top, 4)
            
            Spacer()
        }
        .padding(12)
        .frame(width: 200)
        .background(themeManager.tertiaryBackgroundColor)
    }
    
    // Helper function to format time in mm:ss.ms format
    private func formatTime(seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let milliseconds = Int((seconds - Double(Int(seconds))) * 100)
        return String(format: "%d:%02d.%02d", minutes, secs, milliseconds)
    }
}

// Preview
#Preview {
    // Create a sample audio item
    let audioItem = AudioItem(
        name: "Sample Audio",
        audioFileURL: URL(string: "file:///sample.wav")!,
        durationInSeconds: 120.5,
        sampleRate: 44100,
        numberOfChannels: 2,
        bitDepth: 16,
        fileFormat: "wav",
        lengthInSamples: 5313000
    )
    
    // Create a sample audio clip
    let clip = AudioClip(
        audioItem: audioItem,
        name: "Test Clip",
        startPositionInBeats: 16.0,
        durationInBeats: 8.0,
        startOffsetInSamples: 0,
        lengthInSamples: 2000000
    )
    
    return AudioBottomSectionControlsView(clip: clip)
        .environmentObject(ThemeManager())
}
