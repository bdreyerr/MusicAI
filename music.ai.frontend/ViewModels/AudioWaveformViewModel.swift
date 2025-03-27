import SwiftUI
import Combine

/// View model for generating and managing waveforms for audio clips
class AudioWaveformViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// Whether the waveform is currently being generated
    @Published var isGenerating: Bool = false
    
    /// Error that occurred during waveform generation
    @Published var generationError: String? = nil
    
    /// The generated waveform data
    @Published var waveformData: [CGFloat] = []
    
    // MARK: - Private Properties
    
    /// Cancellable for async operations
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /// Create a singleton instance for shared access
    static let shared = AudioWaveformViewModel()
    
    /// Private initializer for singleton pattern
    private init() {}
    
    // MARK: - Public Methods
    
    /// Generates a waveform for the specified audio file and returns it directly
    /// - Parameters:
    ///   - filePath: Path to the audio file
    ///   - sampleCount: Number of samples to generate in the waveform
    ///   - completion: Completion handler called when generation is complete
    /// - Returns: Boolean indicating if generation started successfully
    func generateWaveform(filePath: URL?, sampleCount: Int, completion: @escaping (Error?) -> Void) {
        isGenerating = true
        var error: Error? = nil
        defer {
            self.isGenerating = false
            completion(error)
        }
        
        // Use a fixed detail level regardless of zoom
        let detailMultiplier = 1.0
        
        // Cap the maximum points to avoid performance issues
        let maxPoints = 2000
        let targetSampleCount = min(maxPoints, Int(Double(sampleCount) * detailMultiplier))
        
        guard let filePath = filePath else {
            // No file, create a random waveform
            waveformData = generateRandomWaveform(sampleCount: targetSampleCount)
            return
        }
        
        // For existing file, attempt to load its audio data
        // In a real implementation, we would analyze the actual audio file here
        // For now, we'll use random waveform as a placeholder
        waveformData = generateRandomWaveform(sampleCount: targetSampleCount)
    }
    
    /// Cancels any active waveform generation
    func cancelGeneration() {
        // Cancel all subscriptions
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        
        // Reset state
        isGenerating = false
        generationError = nil
        
        // Notify observers
        objectWillChange.send()
    }
    
    /// Generates a simple random waveform for placeholder purposes
    /// - Parameter sampleCount: Number of points in the generated waveform
    /// - Returns: Array of random waveform data points
    func generateRandomWaveform(sampleCount: Int = 500) -> [CGFloat] {
        var waveform = [CGFloat]()
        
        // Generate random values with some smoothing for more realistic waveform
        var lastValue: CGFloat = CGFloat.random(in: -0.3...0.3)
        
        for _ in 0..<sampleCount {
            // Add some continuity by using the previous value
            let newValue = lastValue + CGFloat.random(in: -0.15...0.15)
            // Clamp to reasonable range
            lastValue = max(-0.8, min(0.8, newValue))
            waveform.append(lastValue)
        }
        
        return normalizeWaveform(waveform)
    }
    
    /// Generates a realistic random waveform that mimics audio patterns
    /// - Parameters:
    ///   - sampleCount: Number of points in the generated waveform
    ///   - seed: Optional seed for reproducible random generation
    /// - Returns: Array of random waveform data points
    func generateRandomWaveform(sampleCount: Int = 500, seed: Int? = nil) -> [CGFloat] {
        var waveform = [CGFloat]()
        
        // Create a multi-layered audio-like waveform with realistic characteristics
        
        // 1. First create a base pattern using several frequencies
        let freqCount = 5 // Number of frequency components
        var frequencies: [CGFloat] = []
        var amplitudes: [CGFloat] = []
        var phases: [CGFloat] = []
        
        // Create random frequency components that will form our base pattern
        for _ in 0..<freqCount {
            // Create frequencies in different ranges to simulate different audio components
            frequencies.append(CGFloat.random(in: 0.05...0.5))
            amplitudes.append(CGFloat.random(in: 0.1...0.8))
            phases.append(CGFloat.random(in: 0...CGFloat.pi * 2))
        }
        
        // 2. Add transient "attack" sections for realism (sudden peaks followed by decay)
        let attackCount = Int(CGFloat(sampleCount) * 0.05) // About 5% of waveform will have attack transients
        var attackPositions: [Int] = []
        var attackAmplitudes: [CGFloat] = []
        var attackDecayRates: [CGFloat] = []
        
        for _ in 0..<attackCount {
            attackPositions.append(Int.random(in: 0..<sampleCount))
            attackAmplitudes.append(CGFloat.random(in: 0.6...1.0))
            attackDecayRates.append(CGFloat.random(in: 0.005...0.05))
        }
        
        // 3. Generate the waveform by combining these elements with smooth transitions
        var prevValue: CGFloat = 0
        let smoothingFactor: CGFloat = 0.3 // How much smoothing to apply between samples (0-1)
        
        for i in 0..<sampleCount {
            let normalizedPosition = CGFloat(i) / CGFloat(sampleCount)
            var combinedValue: CGFloat = 0
            
            // Sum the sine components with their frequency, amplitude and phase
            for j in 0..<freqCount {
                combinedValue += sin(normalizedPosition * CGFloat.pi * 2 * frequencies[j] * CGFloat(sampleCount) + phases[j]) * amplitudes[j]
            }
            
            // Apply any attack transients that might occur at this position
            for j in 0..<attackCount {
                let distanceFromAttack = abs(i - attackPositions[j])
                if distanceFromAttack < Int(1.0 / attackDecayRates[j]) {
                    // Apply an exponential decay from the attack point
                    let attackContribution = attackAmplitudes[j] * exp(-CGFloat(distanceFromAttack) * attackDecayRates[j])
                    // Add it to the signal, but only in the forward direction from the attack
                    if i >= attackPositions[j] {
                        combinedValue += attackContribution
                    }
                }
            }
            
            // Add a small amount of noise for texture
            let noise = CGFloat.random(in: -0.1...0.1)
            combinedValue += noise * 0.1
            
            // Apply smoothing with previous sample for continuity
            let smoothedValue = combinedValue * (1 - smoothingFactor) + prevValue * smoothingFactor
            
            // Clamp to ensure we stay in a reasonable range
            let clampedValue = max(-1.0, min(1.0, smoothedValue))
            waveform.append(clampedValue)
            prevValue = clampedValue
        }
        
        // 4. Final processing to ensure good dynamics
        return normalizeWaveform(waveform)
    }
    
    // MARK: - Waveform Processing Methods
    
    /// Normalizes waveform data to fit within a specific height range
    /// - Parameters:
    ///   - waveformData: Raw waveform data
    ///   - maxHeight: Maximum height for normalization
    /// - Returns: Normalized waveform data
    func normalizeWaveform(_ waveformData: [CGFloat], maxHeight: CGFloat = 1.0) -> [CGFloat] {
        guard !waveformData.isEmpty else { return [] }
        
        // Find the maximum amplitude in the data
        let maxAmplitude = waveformData.reduce(0) { max($0, abs($1)) }
        
        // If max amplitude is essentially zero, return flat line at half height
        if maxAmplitude < 0.0001 {
            return Array(repeating: maxHeight / 2, count: waveformData.count)
        }
        
        // Scale all values to the desired height range (-maxHeight/2 to maxHeight/2)
        return waveformData.map { value in
            let normalizedValue = value / maxAmplitude
            return normalizedValue * maxHeight
        }
    }
    
    /// Resamples waveform data to a different sample count
    /// - Parameters:
    ///   - waveformData: Original waveform data
    ///   - targetCount: Desired number of samples
    /// - Returns: Resampled waveform data
    func resampleWaveform(_ waveformData: [CGFloat], targetCount: Int) -> [CGFloat] {
        guard !waveformData.isEmpty else { return [] }
        guard targetCount > 0 else { return [] }
        
        // If the target count is the same, return the original data
        if waveformData.count == targetCount {
            return waveformData
        }
        
        var result = [CGFloat](repeating: 0.0, count: targetCount)
        
        // Calculate the scaling factor between the two sample counts
        let scaleFactor = Double(waveformData.count - 1) / Double(targetCount - 1)
        
        for i in 0..<targetCount {
            // Calculate the corresponding position in the source data
            let sourcePos = Double(i) * scaleFactor
            
            // Get the integer parts of the position
            let sourceIdx = Int(sourcePos)
            let nextIdx = min(sourceIdx + 1, waveformData.count - 1)
            
            // Get the fractional part for interpolation
            let fraction = sourcePos - Double(sourceIdx)
            
            // Linearly interpolate between adjacent samples
            result[i] = waveformData[sourceIdx] * CGFloat(1.0 - fraction) + 
                        waveformData[nextIdx] * CGFloat(fraction)
        }
        
        return result
    }
} 
