//
//  ClipSectionWaveformView.swift
//  music.ai.frontend
//
//  Created by Ben Dreyer on 3/29/25.
//

import SwiftUI

/// A specialized view for rendering just the clip section of a waveform
struct ClipSectionWaveformView: View {
    let samples: [Float]
    let totalSamples: Int
    let clipStartSample: Int
    let clipLengthSamples: Int
    let width: CGFloat
    let height: CGFloat
    let stripeWidth: CGFloat
    let stripeSpacing: CGFloat
    let color: Color
    var channelLabel: String? = nil // Optional channel label (L or R)
    
    // Compute a unique ID for this waveform state to prevent unnecessary redraws
    private var waveformId: String {
        // Hash the samples array to detect changes
        let samplesHash = samples.count > 0 ? "\(samples.count)-\(samples.first!)-\(samples.last!)" : "empty"
        // Only include parameters that should trigger a redraw when changed
        return "\(samplesHash)-\(clipStartSample)-\(clipLengthSamples)-\(width)-\(height)"
    }
    
    var body: some View {
        // Use direct Canvas with caching via the id modifier
        Canvas { context, size in
            drawClipSectionWaveform(in: context, size: size)
        }
        .frame(width: width, height: height)
        .drawingGroup() // Enable Metal acceleration
        .id(waveformId) // Only redraw when relevant parameters change
        .overlay(
            // Show channel label if provided
            Group {
                if let label = channelLabel {
                    Text(label)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(2)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(2)
                        .position(x: 8, y: 8)
                }
            }
        )
    }
    
    private func drawClipSectionWaveform(in context: GraphicsContext, size: CGSize) {
        guard !samples.isEmpty, clipStartSample >= 0, clipLengthSamples > 0 else { return }
        
        let centerY = size.height / 2.0
        
        // Use smaller stripeWidth and spacing for more detailed visualization
        let effectiveStripeWidth = min(stripeWidth, 1.5)
        let effectiveSpacing = max(0.5, stripeSpacing / 4)
        let barWidth = effectiveStripeWidth + effectiveSpacing
        
        // Calculate how many bars we can fit
        let totalBars = Int(size.width / barWidth) + 1
        
        // Calculate which portion of the original samples to use
        let clipStartRatio = Double(clipStartSample) / Double(totalSamples)
        let clipEndRatio = Double(clipStartSample + clipLengthSamples) / Double(totalSamples)
        
        // Draw the waveform bars
        for i in 0..<totalBars {
            let x = CGFloat(i) * barWidth
            
            // Skip if we're out of bounds
            if x >= size.width {
                continue
            }
            
            // Calculate the position within the clip as a ratio (0.0 to 1.0)
            let positionInClip = Double(i) / Double(totalBars)
            
            // Map this position to the actual sample in the full audio file
            let sampleRatio = clipStartRatio + positionInClip * (clipEndRatio - clipStartRatio)
            let sampleIndex = min(Int(sampleRatio * Double(samples.count)), samples.count - 1)
            
            // Get sample value (normalized to 0.0-1.0 range)
            var sampleValue = abs(samples[sampleIndex])
            sampleValue = min(sampleValue, 1.0) // Cap at 1.0
            
            // Calculate bar height based on sample value
            let barHeight = sampleValue * Float(centerY) * 1.8 // Slightly increase height for visual impact
            
            // Only draw if bar has height
            if barHeight > 0.01 {
                // Draw top part of bar (above center line)
                let topRect = CGRect(
                    x: x,
                    y: centerY - CGFloat(barHeight),
                    width: effectiveStripeWidth + 0.5, // Add a small overlap to prevent gaps
                    height: CGFloat(barHeight)
                )
                
                // Draw bottom part of bar (below center line)
                let bottomRect = CGRect(
                    x: x,
                    y: centerY,
                    width: effectiveStripeWidth + 0.5, // Add a small overlap to prevent gaps
                    height: CGFloat(barHeight)
                )
                
                // Create paths for the bars
                let topPath = Path(topRect)
                let bottomPath = Path(bottomRect)
                
                // Draw the bars with the appropriate color
                context.fill(topPath, with: .color(color))
                context.fill(bottomPath, with: .color(color))
            }
        }
    }
}
