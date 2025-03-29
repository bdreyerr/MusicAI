import Foundation
import AVFoundation
import SwiftUI
import GameKit

/// Utility class for generating waveform data from audio files
class AudioWaveformGenerator {
    
    /// Generate waveforms for an audio file, with separate waveforms for stereo channels if applicable
    /// - Parameters:
    ///   - url: The URL of the audio file
    ///   - isStereo: Whether to generate separate stereo channels (if false, only mono)
    ///   - color: Color for the waveform
    ///   - sampleRate: Optional target sample rate, determines number of samples in relation to file duration
    /// - Returns: A tuple containing (monoWaveform, leftWaveform, rightWaveform)
    static func generateWaveformsFromAudioUrl(url: URL, 
                                             isStereo: Bool = false,
                                             color: Color? = nil, 
                                             sampleRate: Float = 100) -> (mono: Waveform?, left: Waveform?, right: Waveform?) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("Audio file not found at path: \(url.path)")
            return (nil, nil, nil)
        }
        
        do {
            // Open the audio file
            let audioFile = try AVAudioFile(forReading: url)
            
            // Get audio file properties
            let fileSampleRate = Float(audioFile.fileFormat.sampleRate)
            let channelCount = audioFile.fileFormat.channelCount
            let frameLengthInSamples = AVAudioFramePosition(audioFile.length)
            let durationInSeconds = Double(frameLengthInSamples) / audioFile.fileFormat.sampleRate
            
            // Calculate target sample count based on duration and desired sample rate
            // This ensures longer files get more samples for better detail
            let targetSampleCount = Int(durationInSeconds * Double(sampleRate))
            
            // Create appropriate waveforms based on stereo flag
            if isStereo && channelCount > 1 {
                // For stereo mode, extract left and right channels
                if let stereoSamples = extractStereoSamples(from: audioFile, sampleCount: targetSampleCount) {
                    // Create left waveform
                    let leftWaveform = Waveform(
                        audioFileURL: url,
                        samples: stereoSamples.left,
                        sampleRate: Double(fileSampleRate),
                        channelCount: 1,
                        strokeWidth: 1.0,
                        stripeSpacing: 1.0,
                        stripeWidth: 1.0,
                        color: color,
                        secondaryColor: color,
                        baseline: 0,
                        zoom: 1.0,
                        isCached: true
                    )
                    
                    // Create right waveform
                    let rightWaveform = Waveform(
                        audioFileURL: url,
                        samples: stereoSamples.right,
                        sampleRate: Double(fileSampleRate),
                        channelCount: 1,
                        strokeWidth: 1.0,
                        stripeSpacing: 1.0,
                        stripeWidth: 1.0,
                        color: color,
                        secondaryColor: color,
                        baseline: 0,
                        zoom: 1.0,
                        isCached: true
                    )
                    
                    // Return stereo waveforms with no mono
                    return (nil, leftWaveform, rightWaveform)
                }
            } else {
                // For mono mode, extract a single channel
                if let monoSamples = extractSamples(from: audioFile, sampleCount: targetSampleCount) {
                    // Create mono waveform
                    let monoWaveform = Waveform(
                        audioFileURL: url,
                        samples: monoSamples,
                        sampleRate: Double(fileSampleRate),
                        channelCount: Int(channelCount),
                        strokeWidth: 1.0,
                        stripeSpacing: 1.0,
                        stripeWidth: 1.0,
                        color: color,
                        secondaryColor: color,
                        baseline: 0,
                        zoom: 1.0,
                        isCached: true
                    )
                    
                    // Return mono waveform with no stereo
                    return (monoWaveform, nil, nil)
                }
            }
        } catch {
            print("Error opening audio file: \(error.localizedDescription)")
        }
        
        // If we get here, something went wrong
        print("Failed to generate waveforms for \(url.lastPathComponent)")
        return (nil, nil, nil)
    }
    
    /// Generate a mono waveform model from an audio file URL (legacy support)
    /// - Parameters:
    ///   - url: The URL of the audio file
    ///   - color: Color for the waveform
    ///   - sampleCount: Number of samples to generate (default: 1000)
    /// - Returns: A Waveform model containing the audio sample data, or nil if generation failed
    static func generateWaveformFromAudioUrl(url: URL, 
                                            color: Color? = nil, 
                                            sampleCount: Int = 1000) -> Waveform? {
        let result = generateWaveformsFromAudioUrl(url: url, isStereo: false, color: color, sampleRate: Float(sampleCount))
        return result.mono
    }
    
    /// Generate a random waveform for testing or placeholder purposes
    /// - Parameters:
    ///   - sampleCount: Number of random samples to generate (default: 1000)
    ///   - amplitude: Maximum amplitude of the random waveform (0.0-1.0, default: 0.8)
    ///   - color: Color for the waveform
    /// - Returns: A Waveform model with random sample data
//    static func generateRandomWaveform(sampleCount: Int = 1000, 
//                                      amplitude: Float = 0.8,
//                                      color: Color? = nil) -> Waveform {
//        // Create array to hold sample data
//        var samples = [Float]()
//        
//        // Generate random samples with some smoothness to simulate real audio
//        var lastValue: Float = 0
//        
//        for _ in 0..<sampleCount {
//            // Generate a random change (-0.1 to 0.1)
//            let change = Float.random(in: -0.1...0.1)
//            
//            // Add it to the last value, keeping within bounds
//            var newValue = lastValue + change
//            
//            // Apply some dampening to create more natural looking waveforms
//            newValue = newValue * 0.95
//            
//            // Make sure we stay within the amplitude range
//            newValue = max(min(newValue, amplitude), -amplitude)
//            
//            // Store the value
//            samples.append(newValue)
//            
//            // Remember this value for the next iteration
//            lastValue = newValue
//        }
//        
//        // Every ~20-30 samples, create a larger peak to simulate transients (like drum hits)
//        let peakInterval = Int.random(in: 20...30)
//        for i in stride(from: Int.random(in: 0...20), to: sampleCount, by: peakInterval) {
//            if i < samples.count {
//                let peakValue = Float.random(in: 0.5...amplitude) * (Bool.random() ? 1 : -1)
//                samples[i] = peakValue
//            }
//        }
//        
//        // Create the waveform with our random data
//        return Waveform(
//            samples: samples,
//            strokeWidth: CGFloat.random(in: 0.8...1.2),
//            stripeSpacing: CGFloat.random(in: 0.5...1.5),
//            stripeWidth: CGFloat.random(in: 0.8...1.2),
//            color: color,
//            secondaryColor: color,
//            baseline: 0,
//            zoom: 1.0,
//            isCached: true
//        )
//    }
    
    /// Generate stereo waveforms with different characteristics for testing
    /// - Parameters:
    ///   - sampleCount: Number of random samples to generate (default: 1000)
    ///   - amplitude: Maximum amplitude of the random waveform (0.0-1.0, default: 0.8)
    ///   - color: Color for the waveforms
    /// - Returns: A tuple containing (monoWaveform, leftWaveform, rightWaveform)
//    static func generateRandomStereoWaveforms(sampleCount: Int = 1000,
//                                             amplitude: Float = 0.8,
//                                             color: Color? = nil) -> (mono: Waveform, left: Waveform, right: Waveform) {
//        let monoWaveform = generateRandomWaveform(sampleCount: sampleCount, amplitude: amplitude, color: color)
//        
//        // Generate left channel with slightly different characteristics
//        let leftWaveform = generateRandomWaveform(
//            sampleCount: sampleCount,
//            amplitude: amplitude * 0.9, // Slightly lower amplitude
//            color: color
//        )
//        
//        // Generate right channel with slightly different characteristics
//        let rightWaveform = leftWaveform
//        
//        return (monoWaveform, leftWaveform, rightWaveform)
//    }
    
    // MARK: - Helper Methods
    
    /// Extract sample data from an audio file
    /// - Parameters:
    ///   - audioFile: The audio file to extract samples from
    ///   - sampleCount: Number of samples to extract
    /// - Returns: An array of normalized sample values (-1.0 to 1.0)
    private static func extractSamples(from audioFile: AVAudioFile, sampleCount: Int) -> [Float]? {
        let format = audioFile.processingFormat
        let frameCount = UInt32(audioFile.length)
        
        // If the audio file is empty, return nil
        if frameCount == 0 {
            return nil
        }
        
        // Create a buffer to read the entire file
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }
        
        do {
            // Position file to the beginning - AVAudioFile doesn't have seek method
            audioFile.framePosition = 0
            
            // Read the entire file
            try audioFile.read(into: buffer)
            
            // Convert to float array
            let channelCount = Int(format.channelCount)
            let samples = Array(UnsafeBufferPointer(start: buffer.floatChannelData?[0], count: Int(buffer.frameLength)))
            
            // Downsample and normalize the samples to get our target count
            let downsampled = downsample(samples: samples, targetCount: sampleCount)
            let normalized = normalize(samples: downsampled)
            
            return normalized
        } catch {
            print("Error reading audio file: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Extract stereo sample data from an audio file
    /// - Parameters:
    ///   - audioFile: The audio file to extract samples from
    ///   - sampleCount: Number of samples to extract
    /// - Returns: A tuple containing arrays of normalized sample values for (mono, left, right) channels
    private static func extractStereoSamples(from audioFile: AVAudioFile, sampleCount: Int) -> (mono: [Float]?, left: [Float]?, right: [Float]?)? {
        let format = audioFile.processingFormat
        let frameCount = UInt32(audioFile.length)
        let channelCount = Int(format.channelCount)
        
        // If the audio file is empty or not stereo, return nil
        if frameCount == 0 || channelCount < 2 {
            return nil
        }
        
        // Create a buffer to read the entire file
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }
        
        do {
            // Position file to the beginning - AVAudioFile doesn't have seek method
            audioFile.framePosition = 0
            
            // Read the entire file
            try audioFile.read(into: buffer)
            
            // Get pointers to channel data
            guard let channelData = buffer.floatChannelData else {
                return nil
            }
            
            // Extract separate channels
            let leftChannel = Array(UnsafeBufferPointer(start: channelData[0], count: Int(buffer.frameLength)))
            let rightChannel = Array(UnsafeBufferPointer(start: channelData[min(1, channelCount - 1)], count: Int(buffer.frameLength)))
            
            // Downsample and normalize each channel
            let downsampledLeft = downsample(samples: leftChannel, targetCount: sampleCount)
            let downsampledRight = downsample(samples: rightChannel, targetCount: sampleCount)
            
            let normalizedLeft = normalize(samples: downsampledLeft)
            let normalizedRight = normalize(samples: downsampledRight)
            
            // For mono, average the two channels
            var monoChannel = [Float](repeating: 0, count: downsampledLeft.count)
            for i in 0..<downsampledLeft.count {
                monoChannel[i] = (downsampledLeft[i] + downsampledRight[i]) / 2.0
            }
            let normalizedMono = normalize(samples: monoChannel)
            
            return (normalizedMono, normalizedLeft, normalizedRight)
        } catch {
            print("Error reading audio file: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Downsample a large array of audio samples to a smaller, more manageable size
    /// - Parameters:
    ///   - samples: The original audio samples
    ///   - targetCount: The desired number of samples
    /// - Returns: A downsampled array of peak values
    private static func downsample(samples: [Float], targetCount: Int) -> [Float] {
        // If we have fewer samples than the target, return the original
        if samples.count <= targetCount {
            return samples
        }
        
        // Calculate samples per point
        let samplesPerPoint = max(1, samples.count / targetCount)
        var result = [Float]()
        result.reserveCapacity(targetCount)
        
        // Process in chunks
        for i in stride(from: 0, to: samples.count, by: samplesPerPoint) {
            let endIdx = min(i + samplesPerPoint, samples.count)
            if i < endIdx {
                // Use peak finding - for each chunk, find the maximum absolute value
                // to preserve important transients
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
    
    /// Normalize an array of audio samples to fit within a specific range
    /// - Parameters:
    ///   - samples: The samples to normalize
    ///   - min: Minimum value (-1.0 by default)
    ///   - max: Maximum value (1.0 by default)
    /// - Returns: Normalized samples
    private static func normalize(samples: [Float], min: Float = -1.0, max: Float = 1.0) -> [Float] {
        // Find the maximum absolute value in the samples
        guard let maxValue = samples.map({ abs($0) }).max(), maxValue > 0 else {
            return samples
        }
        
        // Calculate the scaling factor
        let scaleFactor = 1.0 / maxValue
        
        // Apply the scaling to each sample
        return samples.map { $0 * scaleFactor }
    }
} 
