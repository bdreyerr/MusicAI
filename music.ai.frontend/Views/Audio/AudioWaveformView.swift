import SwiftUI

/// View for displaying audio waveforms
struct AudioWaveformView: View {
    // MARK: - Properties
    
    /// Array of waveform data points
    let waveformData: [CGFloat]
    
    /// Color of the waveform
    var color: Color
    
    /// Background color of the waveform view
    var backgroundColor: Color = .clear
    
    /// Optional gradient for the waveform
    var gradient: Gradient? = nil
    
    /// Whether to mirror the waveform vertically (creating a symmetric display)
    var mirrored: Bool = false
    
    /// Vertical scale factor for the waveform
    var scale: CGFloat = 1.0
    
    /// Line width for the waveform
    var lineWidth: CGFloat = 1.0
    
    /// Spacing between waveform points
    var spacing: CGFloat = 2.0
    
    /// The style of the waveform
    var style: WaveformStyle = .line
    
    /// Whether the waveform is currently being loaded
    var isLoading: Bool = false
    
    /// Zoom level (pixels per beat) for adaptive detail
    var zoomLevel: CGFloat = 10.0
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            if isLoading {
                // Loading indicator
                loadingView
            } else if waveformData.isEmpty {
                // Placeholder when no data is available
                emptyWaveformView
            } else {
                // Actual waveform display
                waveformView(in: geometry)
            }
        }
    }
    
    // MARK: - Private Views
    
    /// View displayed when waveform is loading
    private var loadingView: some View {
        ZStack {
            backgroundColor
            
            VStack {
                ProgressView()
                    .scaleEffect(0.7)
                
                Text("Loading waveform...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    /// View displayed when waveform data is empty
    private var emptyWaveformView: some View {
        ZStack {
            backgroundColor
            
            Rectangle()
                .foregroundColor(color.opacity(0.2))
        }
    }
    
    /// The main waveform visualization
    private func waveformView(in geometry: GeometryProxy) -> some View {
        ZStack {
            backgroundColor
            
            Group {
                switch style {
                case .line:
                    lineStyleWaveform(in: geometry)
                case .bars:
                    barsStyleWaveform(in: geometry)
                case .filled:
                    filledStyleWaveform(in: geometry)
                }
            }
        }
    }
    
    /// Calculate optimal number of points to display based on available width, with fixed density
    private func adaptivePointCount(in geometry: GeometryProxy) -> Int {
        let width = geometry.size.width
        
        // Use a consistent point density for all zoom levels
        // This creates a simpler, more predictable approach
        let pointMultiplier = 1.0 // Fixed density for all zoom levels
        
        // Calculate base points based on available width
        let basePoints = Int(width * pointMultiplier)
        
        // Cap the maximum number of points to prevent performance issues
        let maxPoints = min(1000, Int(width * 1.5))
        let targetCount = min(maxPoints, basePoints)
        
        // Cap to available data and ensure minimum points
        return min(waveformData.count, max(20, targetCount))
    }
    
    /// Resample the waveform data to match the appropriate level of detail with optimized performance
    private func adaptiveWaveformData(in geometry: GeometryProxy) -> [CGFloat] {
        // No data available
        if waveformData.isEmpty {
            return []
        }
        
        let targetCount = adaptivePointCount(in: geometry)
        
        // If we have exactly the right amount or need more points than available,
        // return the original data
        if targetCount >= waveformData.count {
            return waveformData
        }
        
        // For better performance at high zoom levels, use a simpler downsampling approach
        // when dealing with large data sets
        if waveformData.count > 5000 && targetCount < waveformData.count / 3 {
            return fastDownsample(targetCount: targetCount)
        } else {
            // Use the more detailed peak-preserving method for smaller data sets
            return peakPreservingDownsample(targetCount: targetCount)
        }
    }
    
    /// Fast downsampling method that preserves overall shape but optimizes for performance
    private func fastDownsample(targetCount: Int) -> [CGFloat] {
        var result = [CGFloat](repeating: 0, count: targetCount)
        let step = Double(waveformData.count) / Double(targetCount)
        
        for i in 0..<targetCount {
            let idx = min(waveformData.count - 1, Int(Double(i) * step))
            result[i] = waveformData[idx]
        }
        
        return result
    }
    
    /// Higher quality downsampling that preserves peaks and important waveform features
    private func peakPreservingDownsample(targetCount: Int) -> [CGFloat] {
        var result = [CGFloat](repeating: 0, count: targetCount)
        let sourcesPerTarget = Double(waveformData.count) / Double(targetCount)
        
        for i in 0..<targetCount {
            let startIdx = Int(Double(i) * sourcesPerTarget)
            let endIdx = min(Int(Double(i + 1) * sourcesPerTarget), waveformData.count)
            
            if startIdx < endIdx {
                // Find peak values in this segment
                var maxAbs: CGFloat = 0
                var peakValue: CGFloat = 0
                
                for j in startIdx..<endIdx {
                    let value = waveformData[j]
                    let absValue = abs(value)
                    if absValue > maxAbs {
                        maxAbs = absValue
                        peakValue = value
                    }
                }
                
                result[i] = peakValue
            } else if i < waveformData.count {
                result[i] = waveformData[i]
            }
        }
        
        return result
    }
    
    /// Renders the waveform as a connected line
    private func lineStyleWaveform(in geometry: GeometryProxy) -> some View {
        let width = geometry.size.width
        let height = geometry.size.height
        let middle = height / 2
        
        // Use adaptive data based on zoom level
        let displayData = adaptiveWaveformData(in: geometry)
        let dataPoints = displayData.count
        
        // Handle edge cases to avoid division by zero
        guard dataPoints > 1 else {
            // Just draw a single line if only one point
            if dataPoints == 1 {
                return AnyView(
                    Rectangle()
                        .frame(width: 2, height: abs(displayData[0]) * middle * scale)
                        .position(x: width/2, y: middle)
                        .foregroundColor(color)
                )
            }
            return AnyView(Color.clear)
        }
        
        let path = Path { path in
            // Calculate exact point spacing to ensure the path fits perfectly within the width
            let pointSpacing = width / CGFloat(dataPoints - 1)
            
            // Start the path at the first point
            let firstPoint = CGPoint(
                x: 0,
                y: middle - (displayData[0] * middle * scale)
            )
            path.move(to: firstPoint)
            
            // Connect points with lines - ensure last point is exactly at the right edge
            for i in 1..<dataPoints {
                let x = i == dataPoints - 1 ? width : pointSpacing * CGFloat(i)
                let y = middle - (displayData[i] * middle * scale)
                path.addLine(to: CGPoint(x: x, y: y))
            }
            
            // If mirrored, add bottom part
            if mirrored {
                // Continue the path back to start, mirroring points
                for i in (0..<dataPoints).reversed() {
                    let x = i == 0 ? 0 : pointSpacing * CGFloat(i)
                    let y = middle + (displayData[i] * middle * scale)
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                
                // Close the path
                path.closeSubpath()
            }
        }
        
        // Apply color or gradient
        if let gradient = gradient {
            return AnyView(
                path.stroke(
                    LinearGradient(gradient: gradient, startPoint: .leading, endPoint: .trailing),
                    lineWidth: lineWidth
                )
            )
        } else {
            return AnyView(
                path.stroke(color, lineWidth: lineWidth)
            )
        }
    }
    
    /// Renders the waveform as vertical bars resembling professional DAW waveforms
    private func barsStyleWaveform(in geometry: GeometryProxy) -> some View {
        let width = geometry.size.width
        let height = geometry.size.height
        let middle = height / 2
        
        // Use adaptive data based on zoom level with higher detail
        let displayData = adaptiveWaveformData(in: geometry)
        let dataPoints = displayData.count
        
        // For realistic audio waveforms, use tighter spacing with very thin bars
        let minBarWidth: CGFloat = 1.0
        let maxBarWidth: CGFloat = 2.0
        
        // Calculate how many bars we can fit based on width
        let idealBarSpacing: CGFloat = 0.5 // Very small gap between bars
        
        // Determine optimal bar width based on zoom level - thinner at lower zoom
        let dynamicBarWidth = max(minBarWidth, min(maxBarWidth, zoomLevel / 50.0))
        
        // Calculate number of bars that can fit with proper spacing
        let barsCount = min(dataPoints, Int(width / (dynamicBarWidth + idealBarSpacing)))
        
        // Recalculate spacing to distribute bars evenly
        let totalBarWidth = dynamicBarWidth * CGFloat(barsCount)
        let remainingSpace = width - totalBarWidth
        let effectiveSpacing = remainingSpace / max(1.0, CGFloat(barsCount - 1))
        
        return ZStack {
            // Display bars with proper positioning
            ForEach(0..<barsCount, id: \.self) { index in
                let sampleIndex = Int(Double(index) / Double(barsCount) * Double(displayData.count))
                let amplitude = abs(displayData[sampleIndex]) * scale
                
                // Use a positioning calculation that ensures even distribution
                let step = (width - dynamicBarWidth) / max(1.0, CGFloat(barsCount - 1))
                let x = index < barsCount - 1 
                    ? CGFloat(index) * step
                    : width - dynamicBarWidth // Ensure last bar is right at the edge
                
                // Adjust amplitude for more dramatic representation at high/low values
                // This emphasizes peaks like in professional DAWs
                let displayAmplitude = adjustAmplitudeForVisualEffect(amplitude)
                
                if mirrored {
                    // For mirrored mode (typical in audio editors)
                    Rectangle()
                        .frame(width: dynamicBarWidth, height: displayAmplitude * middle)
                        .position(x: x + dynamicBarWidth/2, y: middle - (displayAmplitude * middle / 2))
                    
                    // Mirror below center line
                    Rectangle()
                        .frame(width: dynamicBarWidth, height: displayAmplitude * middle)
                        .position(x: x + dynamicBarWidth/2, y: middle + (displayAmplitude * middle / 2))
                } else {
                    // Single bar from center
                    Rectangle()
                        .frame(width: dynamicBarWidth, height: displayAmplitude * middle * 2)
                        .position(x: x + dynamicBarWidth/2, y: middle)
                }
            }
        }
        .if(gradient != nil) { view in
            // Apply gradient if provided
            view.foregroundStyle(
                LinearGradient(gradient: gradient!, startPoint: .top, endPoint: .bottom)
            )
        }
        .foregroundColor(gradient == nil ? color : nil)
    }
    
    /// Adjusts amplitude values to create more visually appealing waveforms
    /// This mimics how professional DAWs display audio by emphasizing peaks
    private func adjustAmplitudeForVisualEffect(_ rawAmplitude: CGFloat) -> CGFloat {
        // Apply a non-linear scaling that emphasizes peaks and reduces mid-level values
        // This creates a more dramatic, professional-looking waveform
        
        // Use a power curve to emphasize peaks (higher exponent = more dramatic peaks)
        let exponent: CGFloat = 0.7 // Values < 1 emphasize small amplitudes, values > 1 emphasize peaks
        
        // Apply the power curve, but ensure minimum visibility for low amplitude signals
        let minVisibleAmplitude: CGFloat = 0.05
        let adjustedValue = pow(rawAmplitude, exponent)
        
        // Ensure even small amplitudes are visible
        return max(adjustedValue, minVisibleAmplitude * rawAmplitude / 0.1)
    }
    
    /// Renders the waveform as a filled shape
    private func filledStyleWaveform(in geometry: GeometryProxy) -> some View {
        let width = geometry.size.width
        let height = geometry.size.height
        let middle = height / 2
        
        // Use adaptive data based on zoom level
        let displayData = adaptiveWaveformData(in: geometry)
        let dataPoints = displayData.count
        
        // Handle edge cases
        guard dataPoints > 0 else {
            return AnyView(Color.clear)
        }
        
        let path = Path { path in
            // Calculate exact point spacing to ensure the path fits perfectly within the width
            let pointSpacing = dataPoints > 1 ? width / CGFloat(dataPoints - 1) : 0
            
            // Start at the bottom left
            path.move(to: CGPoint(x: 0, y: middle))
            
            // Draw the top outline - ensure last point is exactly at the right edge
            for i in 0..<dataPoints {
                let x = i == dataPoints - 1 ? width : pointSpacing * CGFloat(i)
                let y = middle - (displayData[i] * middle * scale)
                path.addLine(to: CGPoint(x: x, y: y))
            }
            
            // Go to the bottom right - ensure we're exactly at the width
            path.addLine(to: CGPoint(x: width, y: middle))
            
            // If mirrored, add bottom part
            if mirrored {
                // Draw the bottom outline - ensure we move from right to left precisely
                for i in (0..<dataPoints).reversed() {
                    let x = i == 0 ? 0 : pointSpacing * CGFloat(i)
                    let y = middle + (displayData[i] * middle * scale)
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            
            // Close the path
            path.closeSubpath()
        }
        
        // Apply color or gradient
        if let gradient = gradient {
            return AnyView(
                path.fill(
                    LinearGradient(gradient: gradient, startPoint: .top, endPoint: .bottom)
                )
            )
        } else {
            return AnyView(
                path.fill(color)
            )
        }
    }
}

// MARK: - View Modifier Extensions

//extension View {
//    /// Conditional modifier to apply a view modifier based on a condition
//    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
//        if condition {
//            transform(self)
//        } else {
//            self
//        }
//    }
//}

// MARK: - Waveform Style Enum

/// Style options for waveform display
enum WaveformStyle {
    /// Connected line display
    case line
    /// Bars display
    case bars
    /// Filled area display
    case filled
}

#Preview {
    // Generate some sample waveform data for the preview
    let sampleData: [CGFloat] = (0..<100).map { idx in
        let value = sin(Double(idx) / 10.0)
        return CGFloat(value) * 0.5
    }
    
    return VStack(spacing: 20) {
        // Line style
        AudioWaveformView(
            waveformData: sampleData,
            color: .blue,
            backgroundColor: Color.gray.opacity(0.1),
            style: .line,
            zoomLevel: 5.0
        )
        .frame(height: 100)
        .padding()
        .border(Color.gray.opacity(0.2))
        
        // Bars style
        AudioWaveformView(
            waveformData: sampleData,
            color: .green,
            backgroundColor: Color.gray.opacity(0.1),
            mirrored: true,
            style: .bars,
            zoomLevel: 20.0
        )
        .frame(height: 100)
        .padding()
        .border(Color.gray.opacity(0.2))
        
        // Filled style with gradient
        AudioWaveformView(
            waveformData: sampleData,
            color: .purple,
            backgroundColor: Color.gray.opacity(0.1),
            gradient: Gradient(colors: [.purple, .blue]),
            mirrored: true,
            style: .filled,
            zoomLevel: 50.0
        )
        .frame(height: 100)
        .padding()
        .border(Color.gray.opacity(0.2))
        
        // Loading state
        AudioWaveformView(
            waveformData: [],
            color: .blue,
            backgroundColor: Color.gray.opacity(0.1),
            isLoading: true
        )
        .frame(height: 100)
        .padding()
        .border(Color.gray.opacity(0.2))
    }
    .padding()
} 
