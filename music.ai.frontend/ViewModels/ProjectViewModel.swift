import SwiftUI
import Combine

class ProjectViewModel: ObservableObject {
    @Published var tempo: Double = 120.0
    @Published var timeSignatureBeats: Int = 4
    @Published var timeSignatureUnit: Int = 4
    @Published var isPlaying: Bool = false
    @Published var currentBeat: Double = 0.0 // Current playback position in beats
    @Published var tracks: [Track] = Track.samples
    
    // Computed property to get time signature as a tuple
    var timeSignature: (Int, Int) {
        (timeSignatureBeats, timeSignatureUnit)
    }
    
    // Convert beat to bar and beat display (1-indexed)
    func barAndBeat(fromBeat beat: Double) -> (Int, Double) {
        let bar = Int(beat) / timeSignatureBeats + 1
        let beatInBar = beat.truncatingRemainder(dividingBy: Double(timeSignatureBeats)) + 1
        return (bar, beatInBar)
    }
    
    // Format current position as "Bar.Beat"
    func formattedPosition() -> String {
        let (bar, beat) = barAndBeat(fromBeat: currentBeat)
        return "\(bar).\(String(format: "%.2f", beat))"
    }
    
    // Play/pause toggle
    func togglePlayback() {
        isPlaying.toggle()
        
        // For demo purposes, increment the currentBeat when playing
        if isPlaying {
            // This would be handled by the audio engine in a real app
            startPlaybackTimer()
        } else {
            stopPlaybackTimer()
        }
    }
    
    // Rewind to beginning
    func rewind() {
        currentBeat = 0.0
    }
    
    // Add a new track
    func addTrack(name: String, type: TrackType) {
        let newTrack = Track(name: name, type: type)
        tracks.append(newTrack)
    }
    
    // Remove a track
    func removeTrack(at index: Int) {
        guard index >= 0 && index < tracks.count else { return }
        tracks.remove(at: index)
    }
    
    // Update a track
    func updateTrack(at index: Int, with updatedTrack: Track) {
        guard index >= 0 && index < tracks.count else { return }
        tracks[index] = updatedTrack
        
        // Handle solo logic - if any track is soloed, mute all non-soloed tracks
        let hasSoloedTrack = tracks.contains { $0.isSolo }
        
        if hasSoloedTrack {
            // If we have any soloed tracks, ensure non-soloed tracks are effectively muted
            // We don't actually change their mute state, just their audibility
            // This is handled in the UI by dimming the track
        }
    }
    
    // MARK: - Private
    
    private var playbackTimer: Timer?
    
    private func startPlaybackTimer() {
        // Update position 60 times per second for smooth playhead movement
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Calculate how much to increment based on tempo
            // At 60 BPM, we advance 1 beat per second
            // At 120 BPM, we advance 2 beats per second
            let beatsPerSecond = self.tempo / 60.0
            let increment = beatsPerSecond / 60.0 // For 60 fps
            
            self.currentBeat += increment
        }
    }
    
    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
} 