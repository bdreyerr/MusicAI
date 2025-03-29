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
    @State private var isEnabled: Bool = true
    @State private var isLooping: Bool = false
    @State private var gain: Double = 0.0
    @State private var pitch: Double = 0.0
    @State private var bpm: Double = 120.0
    
    var body: some View {
        VStack(spacing: 0) {
            // Top section - Clip header info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    // Enable/disable toggle
                    Button(action: {
                        isEnabled.toggle()
                    }) {
                        Image(systemName: isEnabled ? "checkmark.square.fill" : "square")
                            .foregroundColor(isEnabled ? themeManager.accentColor : themeManager.secondaryTextColor)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    
                    // Clip name
                    Text(clip.name)
                        .font(.headline)
                        .foregroundColor(themeManager.primaryTextColor)
                        .lineLimit(1)
                }
                
                // File info
                Text(clip.audioItem.audioFileURL.lastPathComponent)
                    .font(.subheadline)
                    .foregroundColor(themeManager.secondaryTextColor)
                    .lineLimit(1)
                
                // Audio specs
                HStack(spacing: 8) {
                    Text("\(String(format: "%.1f", clip.audioItem.sampleRate / 1000)) kHz")
                        .font(.caption)
                        .foregroundColor(themeManager.secondaryTextColor)
                    
                    Text("\(clip.audioItem.bitDepth)-Bit")
                        .font(.caption)
                        .foregroundColor(themeManager.secondaryTextColor)
                    
                    Text("\(clip.audioItem.numberOfChannels)Ch")
                        .font(.caption)
                        .foregroundColor(themeManager.secondaryTextColor)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(clip.color ?? themeManager.accentColor.opacity(0.2))
            
            Divider()
                .background(themeManager.secondaryBorderColor)
            
            // Middle section - Position controls
            VStack(alignment: .leading, spacing: 6) {
                // Start position
                HStack {
                    Text("Start")
                        .font(.caption)
                        .foregroundColor(themeManager.secondaryTextColor)
                        .frame(width: 40, alignment: .leading)
                    
                    Text(formatBeatPosition(clip.startPositionInBeats))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(themeManager.primaryTextColor)
                    
                    Spacer()
                    
                    Button(action: {
                        // Would set start position
                    }) {
                        Text("Set")
                            .font(.caption)
                            .foregroundColor(themeManager.accentColor)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
                
                // End position
                HStack {
                    Text("End")
                        .font(.caption)
                        .foregroundColor(themeManager.secondaryTextColor)
                        .frame(width: 40, alignment: .leading)
                    
                    Text(formatBeatPosition(clip.endBeat))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(themeManager.primaryTextColor)
                    
                    Spacer()
                    
                    Button(action: {
                        // Would set end position
                    }) {
                        Text("Set")
                            .font(.caption)
                            .foregroundColor(themeManager.accentColor)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
                
                // Length display
                HStack {
                    Text("Length")
                        .font(.caption)
                        .foregroundColor(themeManager.secondaryTextColor)
                        .frame(width: 40, alignment: .leading)
                    
                    Spacer()
                    
                    Text(formatLength(clip.durationInBeats))
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundColor(themeManager.secondaryTextColor)
                }
                
                // Loop toggle
                Toggle(isOn: $isLooping) {
                    Text("Loop")
                        .font(.caption)
                        .foregroundColor(themeManager.secondaryTextColor)
                }
                .toggleStyle(SwitchToggleStyle(tint: themeManager.accentColor))
                .padding(.top, 2)
            }
            .padding(10)
            .background(themeManager.tertiaryBackgroundColor.opacity(0.3))
            
            Divider()
                .background(themeManager.secondaryBorderColor)
            
            // Bottom section - Audio controls
            VStack(spacing: 8) {
                // Top row - Buttons
                HStack {
                    // Warp button
                    Button(action: {
                        // Warp action
                    }) {
                        Text("Warp")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    
                    // Follow button
                    Button(action: {
                        // Follow action
                    }) {
                        Text("Follow")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(themeManager.secondaryBackgroundColor)
                            .foregroundColor(themeManager.secondaryTextColor)
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(themeManager.secondaryBorderColor, lineWidth: 1)
                            )
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    
                    Spacer()
                    
                    // Gain text
                    Text("Gain")
                        .font(.caption)
                        .foregroundColor(themeManager.secondaryTextColor)
                }
                
                // Middle row - Gain slider
                HStack {
                    // Mode dropdown
                    Menu {
                        Button("Beats", action: {})
                        Button("Repitch", action: {})
                        Button("Complex", action: {})
                        Button("Transients", action: {})
                    } label: {
                        Text("Beats")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(themeManager.tertiaryBackgroundColor)
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(themeManager.secondaryBorderColor, lineWidth: 1)
                            )
                            .foregroundColor(themeManager.primaryTextColor)
                    }
                    
                    Spacer()
                    
                    // Gain value
                    Text(String(format: "%.2f dB", gain))
                        .font(.caption)
                        .foregroundColor(themeManager.secondaryTextColor)
                        .frame(width: 60, alignment: .trailing)
                }
                
                // Gain slider
                Slider(value: $gain, in: -36...12, step: 0.1)
                    .accentColor(themeManager.accentColor)
                
                // Bottom row - BPM and Pitch controls
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("BPM")
                            .font(.caption2)
                            .foregroundColor(themeManager.secondaryTextColor)
                        
                        HStack(spacing: 3) {
                            Text(String(format: "%.2f", bpm))
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(themeManager.primaryTextColor)
                            
                            // BPM adjustment buttons
                            HStack(spacing: 0) {
                                Button(action: { bpm -= 0.01 }) {
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 8))
                                        .foregroundColor(themeManager.secondaryTextColor)
                                        .frame(width: 12, height: 12)
                                }
                                Button(action: { bpm += 0.01 }) {
                                    Image(systemName: "chevron.up")
                                        .font(.system(size: 8))
                                        .foregroundColor(themeManager.secondaryTextColor)
                                        .frame(width: 12, height: 12)
                                }
                            }
                            .padding(.leading, 2)
                            .background(themeManager.secondaryBackgroundColor)
                            .cornerRadius(3)
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke(themeManager.secondaryBorderColor, lineWidth: 1)
                            )
                        }
                    }
                    .padding(.vertical, 2)
                    .padding(.horizontal, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(themeManager.tertiaryBackgroundColor.opacity(0.5))
                    )
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Pitch")
                            .font(.caption2)
                            .foregroundColor(themeManager.secondaryTextColor)
                        
                        HStack {
                            Text(String(format: "%+d", Int(pitch)))
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(themeManager.primaryTextColor)
                                .frame(width: 24, alignment: .center)
                        }
                        .padding(.vertical, 2)
                        .padding(.horizontal, 4)
                        .background(themeManager.secondaryBackgroundColor)
                        .cornerRadius(3)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(themeManager.secondaryBorderColor, lineWidth: 1)
                        )
                    }
                }
                
                // Bottom row - RAM/HDD selector
                HStack {
                    Spacer()
                    
                    Button(action: {
                        // RAM option
                    }) {
                        Text("RAM")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(themeManager.secondaryBackgroundColor)
                            .foregroundColor(themeManager.secondaryTextColor)
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(themeManager.secondaryBorderColor, lineWidth: 1)
                            )
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    
                    Button(action: {
                        // HDD option
                    }) {
                        Text("HDD")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
            .padding(10)
            .background(themeManager.tertiaryBackgroundColor.opacity(0.5))
            
            Spacer() // Fill remaining space
        }
        .frame(width: 220)
        .background(themeManager.secondaryBackgroundColor)
    }
    
    // Helper function to format beat position (e.g., "8. 2.")
    private func formatBeatPosition(_ beats: Double) -> String {
        let bars = Int(beats) / 4
        let beatsInBar = beats.truncatingRemainder(dividingBy: 4)
        return String(format: "%d. %d.", bars, Int(beatsInBar) + 1)
    }
    
    // Helper function to format length (e.g., "1. 0. 0")
    private func formatLength(_ beats: Double) -> String {
        let bars = Int(beats) / 4
        let beatsInBar = Int(beats.truncatingRemainder(dividingBy: 4))
        let fractionalBeats = Int((beats - Double(Int(beats))) * 100)
        return String(format: "%d. %d. %d", bars, beatsInBar, fractionalBeats)
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
        name: "trav",
        audioFileURL: URL(string: "file:///trav.mp3")!,
        durationInSeconds: 120.5,
        sampleRate: 44100,
        numberOfChannels: 2,
        bitDepth: 16,
        fileFormat: "mp3",
        lengthInSamples: 5313000
    )
    
    // Create a sample audio clip
    let clip = AudioClip(
        audioItem: audioItem,
        name: "Clip",
        startPositionInBeats: 8.0,
        durationInBeats: 4.0,
        startOffsetInSamples: 0,
        lengthInSamples: 2000000
    )
    
    return AudioBottomSectionControlsView(clip: clip)
        .environmentObject(ThemeManager())
}
