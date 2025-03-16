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
    
    // Reference to the timeline state
    var timelineState: TimelineStateViewModel? = nil
    
    // MIDI view model for handling MIDI-related operations
    lazy var midiViewModel: MidiViewModel = {
        let viewModel = MidiViewModel(projectViewModel: self, timelineState: timelineState)
        return viewModel
    }()
    
    // Audio view model for handling audio-related operations
    lazy var audioViewModel: AudioViewModel = {
        let viewModel = AudioViewModel(projectViewModel: self, timelineState: timelineState)
        return viewModel
    }()
    
    // Effects view model for handling effects-related operations
    lazy var effectsViewModel: EffectsViewModel = {
        let viewModel = EffectsViewModel(projectViewModel: self)
        return viewModel
    }()
    
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
    
    // Computed property to get the currently selected track
    var selectedTrack: Track? {
        tracks.first { $0.id == selectedTrackId }
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
        // If we're starting playback and there's an active selection,
        // ensure the playhead is at the start of the selection
        if !isPlaying {
            if let timelineState = findTimelineState(), timelineState.selectionActive {
                let (start, _) = timelineState.normalizedSelectionRange
                seekToBeat(start)
            }
        }
        
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
        guard index >= 0 && index < tracks.count else {
            print("❌ PROJECT VM: Failed to update track - index \(index) out of bounds")
            return
        }
        
        let oldTrack = tracks[index]
        print("📝 PROJECT VM: Updating track at index \(index): \(oldTrack.name) (id: \(oldTrack.id))")
        
        // Check if audio clips are changing
        if oldTrack.type == .audio {
            print("📝 PROJECT VM: Audio track - Old clip count: \(oldTrack.audioClips.count), New clip count: \(updatedTrack.audioClips.count)")
            
            // Log details about the clips
            if oldTrack.audioClips.count != updatedTrack.audioClips.count {
                print("📝 PROJECT VM: Audio clip count changed")
            }
            
            // Check for position changes in clips
            for (i, newClip) in updatedTrack.audioClips.enumerated() {
                if let oldClip = oldTrack.audioClips.first(where: { $0.id == newClip.id }) {
                    if oldClip.startBeat != newClip.startBeat {
                        print("📝 PROJECT VM: Audio clip \(newClip.name) position changed from \(oldClip.startBeat) to \(newClip.startBeat)")
                    }
                } else {
                    print("📝 PROJECT VM: New audio clip added: \(newClip.name) at position \(newClip.startBeat)")
                }
            }
        }
        
        // Check if MIDI clips are changing
        if oldTrack.type == .midi {
            print("📝 PROJECT VM: MIDI track - Old clip count: \(oldTrack.midiClips.count), New clip count: \(updatedTrack.midiClips.count)")
            
            // Log details about the clips
            if oldTrack.midiClips.count != updatedTrack.midiClips.count {
                print("📝 PROJECT VM: MIDI clip count changed")
            }
            
            // Check for position changes in clips
            for (i, newClip) in updatedTrack.midiClips.enumerated() {
                if let oldClip = oldTrack.midiClips.first(where: { $0.id == newClip.id }) {
                    if oldClip.startBeat != newClip.startBeat {
                        print("📝 PROJECT VM: MIDI clip \(newClip.name) position changed from \(oldClip.startBeat) to \(newClip.startBeat)")
                    }
                } else {
                    print("📝 PROJECT VM: New MIDI clip added: \(newClip.name) at position \(newClip.startBeat)")
                }
            }
        }
        
        tracks[index] = updatedTrack
        print("✅ PROJECT VM: Track updated successfully")
        
        // Handle solo logic - if any track is soloed, mute all non-soloed tracks
        let hasSoloedTrack = tracks.contains { $0.isSolo }
        
        if hasSoloedTrack {
            // If we have any soloed tracks, ensure non-soloed tracks are effectively muted
            // We don't actually change their mute state, just their audibility
            // This is handled in the UI by dimming the track
        }
        
        // Notify observers that tracks have been updated
        print("📢 PROJECT VM: Notifying observers of track update")
        objectWillChange.send()
        print("📢 PROJECT VM: Observers notified")
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
    
    // Helper method to find the TimelineState if it exists
    private func findTimelineState() -> TimelineStateViewModel? {
        // Simply return the timelineState property
        // This is now properly set in TimelineView's onAppear
        return timelineState
    }
} 
