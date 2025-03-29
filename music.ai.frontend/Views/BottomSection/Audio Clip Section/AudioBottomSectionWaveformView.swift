//
//  AudioBottomSectionWaveformView.swift
//  music.ai.frontend
//
//  Created by Ben Dreyer on 3/28/25.
//

import SwiftUI

struct AudioBottomSectionWaveformView: View {
    let clip: AudioClip
    @EnvironmentObject var themeManager: ThemeManager
    @State private var zoomLevel: Double = 1.0
    
    var body: some View {
        VStack(spacing: 0) {
            // Waveform view with scroll view wrapper
            GeometryReader { geometry in
                if let audioItemWaveform = clip.audioItem.waveform {
                    ScrollView(.horizontal, showsIndicators: false) {
                        ScrollViewReader { scrollProxy in
                            ZStack(alignment: .leading) {
                                // Position indicator for clip center
                                Color.clear
                                    .frame(width: 1, height: 1)
                                    .id("clipCenter")
                                    .frame(width: geometry.size.width * CGFloat(zoomLevel))
                                    .offset(x: calculateClipCenterOffset(totalWidth: geometry.size.width * CGFloat(zoomLevel)))
                                
                                // Actual waveform view
                                FullAudioItemWaveformView(
                                    waveform: audioItemWaveform,
                                    clip: clip,
                                    width: geometry.size.width * CGFloat(zoomLevel),
                                    height: geometry.size.height - 40,
                                    zoomLevel: zoomLevel
                                )
                                .frame(
                                    width: geometry.size.width * CGFloat(zoomLevel), 
                                    height: geometry.size.height - 40
                                )
                                .padding(.vertical, 20)
                            }
                            .onChange(of: zoomLevel) { _ in
                                // When zoom changes, scroll to the clip center
                                scrollToClipCenter(proxy: scrollProxy)
                            }
                            .onAppear {
                                // Scroll to clip center when the view appears
                                scrollToClipCenter(proxy: scrollProxy)
                            }
                        }
                    }
                    // Ensure the scroll view fills the available space
                    .frame(width: geometry.size.width, height: geometry.size.height)
                } else {
                    // Placeholder if waveform is not available
                    HStack {
                        Spacer()
                        VStack {
                            Image(systemName: "waveform.slash")
                                .font(.system(size: 32))
                                .foregroundColor(themeManager.secondaryTextColor)
                            Text("Waveform not available")
                                .foregroundColor(themeManager.secondaryTextColor)
                        }
                        Spacer()
                    }
                }
            }
            
            // Bottom controls
            HStack {
                // Zoom out button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        zoomLevel = max(0.25, zoomLevel - 0.25)
                    }
                }) {
                    Image(systemName: "minus.magnifyingglass")
                        .foregroundColor(themeManager.primaryTextColor)
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(zoomLevel <= 0.25)
                .opacity(zoomLevel <= 0.25 ? 0.5 : 1.0)
                
                // Zoom slider
                Slider(
                    value: $zoomLevel,
                    in: 0.25...4.0,
                    step: 0.25
                )
                .accentColor(themeManager.accentColor)
                
                // Zoom in button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        zoomLevel = min(4.0, zoomLevel + 0.25)
                    }
                }) {
                    Image(systemName: "plus.magnifyingglass")
                        .foregroundColor(themeManager.primaryTextColor)
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(zoomLevel >= 4.0)
                .opacity(zoomLevel >= 4.0 ? 0.5 : 1.0)
                
                // Zoom text
                Text("\(Int(zoomLevel * 100))%")
                    .font(.caption)
                    .foregroundColor(themeManager.secondaryTextColor)
                    .frame(width: 50, alignment: .trailing)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .padding(.bottom, 8)
            .background(themeManager.tertiaryBackgroundColor)
        }
        .background(themeManager.secondaryBackgroundColor)
    }
    
    // Helper function to scroll to the clip center
    private func scrollToClipCenter(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.3)) {
            proxy.scrollTo("clipCenter", anchor: .center)
        }
    }
    
    // Calculate the offset for the clip center marker
    private func calculateClipCenterOffset(totalWidth: CGFloat) -> CGFloat {
        let clipStartRatio = Double(clip.startOffsetInSamples) / Double(clip.audioItem.lengthInSamples)
        let clipEndRatio = Double(clip.startOffsetInSamples + clip.lengthInSamples) / Double(clip.audioItem.lengthInSamples)
        let clipCenterRatio = (clipStartRatio + clipEndRatio) / 2.0
        
        return totalWidth * CGFloat(clipCenterRatio)
    }
}

/// A view that renders the full audio item waveform with the clip section highlighted
struct FullAudioItemWaveformView: View {
    let waveform: Waveform
    let clip: AudioClip
    let width: CGFloat
    let height: CGFloat
    let zoomLevel: Double
    
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                themeManager.secondaryBackgroundColor.opacity(0.2)
                
                // Draw the single waveform with color segmentation
                if let samples = waveform.samples, !samples.isEmpty {
                    ColoredWaveformView(
                        samples: samples,
                        totalSamples: Int(clip.audioItem.lengthInSamples),
                        clipStartSample: Int(clip.startOffsetInSamples),
                        clipLengthSamples: Int(clip.lengthInSamples),
                        width: geometry.size.width,
                        height: geometry.size.height,
                        stripeWidth: waveform.stripeWidth,
                        stripeSpacing: waveform.stripeSpacing,
                        baseColor: themeManager.secondaryTextColor.opacity(0.5),
                        highlightColor: clip.color ?? themeManager.accentColor
                    )
                    
                    // Add a subtle highlight behind the clip section
                    let clipStartRatio = Double(clip.startOffsetInSamples) / Double(clip.audioItem.lengthInSamples)
                    let clipWidthRatio = Double(clip.lengthInSamples) / Double(clip.audioItem.lengthInSamples)
                    
                    Rectangle()
                        .fill(themeManager.accentColor.opacity(0.1))
                        .frame(
                            width: geometry.size.width * CGFloat(clipWidthRatio),
                            height: geometry.size.height
                        )
                        .offset(x: geometry.size.width * CGFloat(clipStartRatio))
                }
            }
            .clipped()
        }
    }
}

/// A view that renders a waveform with different colors for the clip section
struct ColoredWaveformView: View {
    let samples: [Float]
    let totalSamples: Int
    let clipStartSample: Int
    let clipLengthSamples: Int
    let width: CGFloat
    let height: CGFloat
    let stripeWidth: CGFloat
    let stripeSpacing: CGFloat
    let baseColor: Color
    let highlightColor: Color
    
    var body: some View {
        Canvas { context, size in
            drawColoredWaveform(in: context, size: size)
        }
        .frame(width: width, height: height)
    }
    
    private func drawColoredWaveform(in context: GraphicsContext, size: CGSize) {
        guard !samples.isEmpty else { return }
        
        let centerY = size.height / 2.0
        
        // Use smaller stripeWidth and spacing for more detailed visualization
        let effectiveStripeWidth = min(stripeWidth, 1.5)
        let effectiveSpacing = max(0.5, stripeSpacing / 4)
        let barWidth = effectiveStripeWidth + effectiveSpacing
        
        // Calculate how many bars we can fit
        let totalBars = Int(size.width / barWidth) + 1
        
        // Calculate clip start and end positions as ratios
        let clipStartRatio = Double(clipStartSample) / Double(totalSamples)
        let clipEndRatio = Double(clipStartSample + clipLengthSamples) / Double(totalSamples)
        
        // Draw the waveform bars
        for i in 0..<totalBars {
            let x = CGFloat(i) * barWidth
            
            // Skip if we're out of bounds
            if x >= size.width {
                continue
            }
            
            // Calculate sample index for this bar
            let sampleRatio = Double(i) / Double(totalBars)
            let sampleIndex = min(Int(sampleRatio * Double(samples.count)), samples.count - 1)
            
            // Get sample value (normalized to 0.0-1.0 range)
            var sampleValue = abs(samples[sampleIndex])
            sampleValue = min(sampleValue, 1.0) // Cap at 1.0
            
            // Calculate bar height based on sample value
            let barHeight = sampleValue * Float(centerY) * 1.8 // Slightly increase height for visual impact
            
            // Only draw if bar has height
            if barHeight > 0.01 {
                // Determine if this bar is within the clip section
                let isInClipRange = sampleRatio >= clipStartRatio && sampleRatio <= clipEndRatio
                let barColor = isInClipRange ? highlightColor : baseColor
                
                // Draw top part of bar (above center line)
                let topRect = CGRect(
                    x: x,
                    y: centerY - CGFloat(barHeight),
                    width: effectiveStripeWidth,
                    height: CGFloat(barHeight)
                )
                
                // Draw bottom part of bar (below center line)
                let bottomRect = CGRect(
                    x: x,
                    y: centerY,
                    width: effectiveStripeWidth,
                    height: CGFloat(barHeight)
                )
                
                // Create paths for the bars
                let topPath = Path(roundedRect: topRect, cornerSize: CGSize(width: 0.5, height: 0.5))
                let bottomPath = Path(roundedRect: bottomRect, cornerSize: CGSize(width: 0.5, height: 0.5))
                
                // Draw the bars with the appropriate color
                context.fill(topPath, with: .color(barColor))
                context.fill(bottomPath, with: .color(barColor))
            }
        }
    }
}

// Preview
#Preview {
    // Create a sample audio item with a waveform
    let sampleWaveform = AudioWaveformGenerator.generateRandomWaveform(color: .blue)
    
    let audioItem = AudioItem(
        name: "Sample Audio",
        audioFileURL: URL(string: "file:///sample.wav")!,
        durationInSeconds: 120.5,
        sampleRate: 44100,
        numberOfChannels: 2,
        bitDepth: 16,
        fileFormat: "wav",
        waveform: sampleWaveform,
        lengthInSamples: 5313000
    )
    
    // Create a sample audio clip that represents only part of the audio item
    let clip = AudioClip(
        audioItem: audioItem,
        name: "Test Clip",
        startPositionInBeats: 16.0,
        durationInBeats: 8.0,
        color: .orange,
        startOffsetInSamples: 1000000, // Start at around 1/5 of the way in
        lengthInSamples: 2000000       // Use about 2/5 of the full audio
    )
    
    return AudioBottomSectionWaveformView(clip: clip)
        .environmentObject(ThemeManager())
        .frame(height: 300)
}
