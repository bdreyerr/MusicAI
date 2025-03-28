import SwiftUI

/// A view that efficiently renders a waveform visualization with striped line style
struct WaveformView: View {
    /// The waveform model to render
    let waveform: Waveform
    
    /// Width of the view
    var width: CGFloat
    
    /// Height of the view
    var height: CGFloat
    
    /// Theme manager for colors
    @EnvironmentObject var themeManager: ThemeManager
    
    /// Resolution - determines how many samples to skip when rendering
    /// Higher value = better performance but less detailed waveform
    var resolution: Int = 1
    
    @State private var optimizedSamples: [Float] = []
    @State private var lastRenderWidth: CGFloat = 0
    @State private var lastRenderHeight: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                themeManager.secondaryBackgroundColor
                    .opacity(0.2)
                
                // Draw the waveform if we have samples
                if let samples = waveform.samples, !samples.isEmpty {
                    // If the dimensions have changed, re-optimize samples
                    Group {
                        if lastRenderWidth != geometry.size.width || lastRenderHeight != geometry.size.height || optimizedSamples.isEmpty {
                            StripedWaveformView(
                                samples: calculateOptimizedSamples(samples: samples, for: geometry.size),
                                width: geometry.size.width,
                                height: geometry.size.height,
                                stripeWidth: waveform.stripeWidth,
                                stripeSpacing: waveform.stripeSpacing,
                                color: waveform.color ?? themeManager.accentColor
                            )
                            .onAppear {
                                DispatchQueue.main.async {
                                    optimizedSamples = calculateOptimizedSamples(samples: samples, for: geometry.size)
                                    lastRenderWidth = geometry.size.width
                                    lastRenderHeight = geometry.size.height
                                }
                            }
                            .onChange(of: geometry.size) { _ in
                                DispatchQueue.main.async {
                                    optimizedSamples = calculateOptimizedSamples(samples: samples, for: geometry.size)
                                    lastRenderWidth = geometry.size.width
                                    lastRenderHeight = geometry.size.height
                                }
                            }
                        } else {
                            StripedWaveformView(
                                samples: optimizedSamples,
                                width: geometry.size.width,
                                height: geometry.size.height,
                                stripeWidth: waveform.stripeWidth,
                                stripeSpacing: waveform.stripeSpacing,
                                color: waveform.color ?? themeManager.accentColor
                            )
                        }
                    }
                } else {
                    // Show placeholder if no samples
//                    PlaceholderWaveformView()
                    Text("Error loading samples for waveform")
                }
            }
        }
        .frame(width: width, height: height)
        .clipShape(Rectangle())
    }
    
    // Get an optimized subset of samples based on the current view size
    private func calculateOptimizedSamples(samples: [Float], for size: CGSize) -> [Float] {
        // Calculate how many samples we need based on the width
        let effectiveResolution = max(1, resolution)
        let availableWidth = max(1, size.width)
        
        // Calculate target number of samples based on the view width
        // We want more samples than actual pixels for better visual density
        let targetSampleCount = Int(availableWidth * 1.5) // 50% more samples than pixels
        
        // If we have fewer samples than needed, use all samples
        if samples.count <= targetSampleCount {
            return samples
        }
        
        // Otherwise, downsample to match the target count
        let samplesPerPoint = max(1, samples.count / targetSampleCount)
        var result: [Float] = []
        result.reserveCapacity(targetSampleCount)
        
        for i in stride(from: 0, to: samples.count, by: samplesPerPoint) {
            let endIdx = min(i + samplesPerPoint, samples.count)
            if i < endIdx {
                // Find the peak value in this range (for better visualization)
                let subRange = Array(samples[i..<endIdx])
                if let maxAbs = subRange.map({ abs($0) }).max() {
                    // Preserve the sign of the original sample with the highest magnitude
                    if let originalSample = subRange.first(where: { abs($0) == maxAbs }) {
                        result.append(originalSample)
                    } else {
                        result.append(subRange.first ?? 0)
                    }
                } else {
                    result.append(samples[i])
                }
            }
        }
        
        return result
    }
}

/// A view that renders a waveform with striped vertical bars
struct StripedWaveformView: View {
    let samples: [Float]
    let width: CGFloat
    let height: CGFloat
    let stripeWidth: CGFloat
    let stripeSpacing: CGFloat
    let color: Color
    
    var body: some View {
        Canvas { context, size in
            // Draw the striped waveform using Canvas for better performance
            drawStripedWaveform(in: context, size: size)
        }
        .frame(width: width, height: height)
    }
    
    private func drawStripedWaveform(in context: GraphicsContext, size: CGSize) {
        guard !samples.isEmpty else { return }
        
        let centerY = size.height / 2.0
        
        // Use smaller stripeWidth and spacing for more detailed visualization
        let effectiveStripeWidth = min(stripeWidth, 1.5)
        let effectiveSpacing = max(0.5, stripeSpacing / 4)
        let barWidth = effectiveStripeWidth + effectiveSpacing
        
        // Calculate how many bars we can fit
        let totalBars = Int(size.width / barWidth) + 1
        
        // Calculate samples per bar
        let samplesPerBar = max(1, samples.count / totalBars)
        
        // Draw the waveform bars
        for i in 0..<totalBars {
            let x = CGFloat(i) * barWidth
            
            // Skip if we're out of bounds
            if x >= size.width {
                continue
            }
            
            // Calculate sample index for this bar
            let sampleIndex = min(i * samplesPerBar, samples.count - 1)
            
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
                
                // Draw the bars with consistent color and opacity
                let renderColor = color.opacity(0.9) // Apply fixed opacity to ensure consistent appearance
                context.fill(topPath, with: .color(renderColor))
                context.fill(bottomPath, with: .color(renderColor))
            }
        }
    }
}

/// A placeholder view for when a waveform doesn't have samples
struct PlaceholderWaveformView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Canvas { context, size in
            let centerY = size.height / 2.0
            let stripeWidth: CGFloat = 1.5
            let stripeSpacing: CGFloat = 0.5
            let barWidth = stripeWidth + stripeSpacing
            let totalBars = Int(size.width / barWidth) + 1
            
            // Draw a placeholder pattern of small bars
            for i in 0..<totalBars {
                let x = CGFloat(i) * barWidth
                
                // Skip if we're out of bounds
                if x >= size.width {
                    continue
                }
                
                // Generate a height using a sine wave pattern
                let phase = Double(i) / 5.0 // Reduce divisor for more frequent waves
                let amplitude = sin(phase) * 0.3 + 0.4 // Range 0.1-0.7
                let barHeight = amplitude * centerY
                
                // Only draw if bar has height
                if barHeight > 0.01 {
                    // Draw top part of bar (above center line)
                    let topRect = CGRect(
                        x: x,
                        y: centerY - barHeight,
                        width: stripeWidth,
                        height: barHeight
                    )
                    
                    // Draw bottom part of bar (below center line)
                    let bottomRect = CGRect(
                        x: x,
                        y: centerY,
                        width: stripeWidth,
                        height: barHeight
                    )
                    
                    // Create paths for the bars
                    let topPath = Path(roundedRect: topRect, cornerSize: CGSize(width: 0.5, height: 0.5))
                    let bottomPath = Path(roundedRect: bottomRect, cornerSize: CGSize(width: 0.5, height: 0.5))
                    
                    // Draw the bars with a consistent faded color
                    let color = themeManager.secondaryTextColor.opacity(0.3)
                    context.fill(topPath, with: .color(color))
                    context.fill(bottomPath, with: .color(color))
                }
            }
        }
    }
}

// MARK: - Previews
struct WaveformView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a sample waveform with random data
        let waveform = AudioWaveformGenerator.generateRandomWaveform(
            color: .blue
        )
        
        // Return the preview
        WaveformView(waveform: waveform, width: 400, height: 100)
            .environmentObject(ThemeManager())
            .previewLayout(.fixed(width: 400, height: 100))
            .padding()
            .background(Color.gray.opacity(0.2))
    }
} 
