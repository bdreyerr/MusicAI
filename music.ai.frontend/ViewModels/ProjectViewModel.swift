import SwiftUI
import Combine

class ProjectViewModel: ObservableObject {
    @Published var tempo: Double = 120.0
    @Published var timeSignatureBeats: Int = 4
    @Published var timeSignatureUnit: Int = 4
    @Published var isPlaying: Bool = false
    @Published var currentBeat: Double = 0.0 // Current playback position in beats
    @Published var tracks: [Track] = Track.samples
    @Published var selectedTrackId: UUID? = nil // ID of the currently selected track
    
    // Initialize with default values
    init() {
        // Select the first track by default if available
        if !tracks.isEmpty {
            selectedTrackId = tracks[0].id
        }
    }
    
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
    
    // Seek to a specific beat position
    func seekToBeat(_ beat: Double) {
        // Ensure beat is not negative
        currentBeat = max(0, beat)
        
        // In a real app, you would also update the audio engine's playback position here
        // For example: audioEngine.seekToPosition(currentBeat)
    }
    
    // Select a track
    func selectTrack(id: UUID?) {
        selectedTrackId = id
    }
    
    // Check if a track is selected
    func isTrackSelected(_ track: Track) -> Bool {
        return track.id == selectedTrackId
    }
    
    // Add a new track
    func addTrack(name: String, type: TrackType, height: CGFloat = 70) {
        var newTrack = Track(name: name, type: type)
        newTrack.height = height
        tracks.append(newTrack)
        
        // If this is the first track, select it automatically
        if tracks.count == 1 {
            selectedTrackId = newTrack.id
        }
    }
    
    // Remove a track
    func removeTrack(at index: Int) {
        guard index >= 0 && index < tracks.count else { return }
        
        let trackToRemove = tracks[index]
        tracks.remove(at: index)
        
        // If we removed the selected track, select another one if available
        if trackToRemove.id == selectedTrackId {
            if !tracks.isEmpty {
                // Select the track at the same index, or the last track if we removed the last one
                let newIndex = min(index, tracks.count - 1)
                selectedTrackId = tracks[newIndex].id
            } else {
                selectedTrackId = nil
            }
        }
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