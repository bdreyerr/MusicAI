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
    
    // Performance optimization settings
    @Published var performanceMode: PerformanceMode = .balanced
    
    // Reference to the timeline state
    var timelineState: TimelineStateViewModel? = nil
    
    // Interaction manager for coordinating gestures and events
    let interactionManager = InteractionManager()
    
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
    
    // Performance mode enum
    enum PerformanceMode {
        case quality    // Prioritize visual quality over performance
        case balanced   // Balance between quality and performance
        case performance // Prioritize performance over visual quality
        
        // UI update frequency in Hz based on performance mode
        var uiUpdateFrequency: Double {
            switch self {
            case .quality:
                return 30.0 // 30 Hz (smoother but more CPU intensive)
            case .balanced:
                return 15.0 // 15 Hz (good balance)
            case .performance:
                return 10.0 // 10 Hz (less smooth but better performance)
            }
        }
        
        // Playback timer frequency in Hz based on performance mode
        var playbackTimerFrequency: Double {
            switch self {
            case .quality:
                return 60.0 // 60 Hz (more accurate timing)
            case .balanced:
                return 60.0 // 60 Hz (accurate timing)
            case .performance:
                return 30.0 // 30 Hz (less accurate but better performance)
            }
        }
    }
    
    // Toggle performance mode
    func togglePerformanceMode() {
        switch performanceMode {
        case .quality:
            performanceMode = .balanced
        case .balanced:
            performanceMode = .performance
        case .performance:
            performanceMode = .quality
        }
        
        // If we're playing, restart the playback timer with the new settings
        if isPlaying {
            stopPlaybackTimer()
            startPlaybackTimer()
        }
    }
    
    // Get the current performance mode name
    func performanceModeName() -> String {
        switch performanceMode {
        case .quality:
            return "Quality"
        case .balanced:
            return "Balanced"
        case .performance:
            return "Performance"
        }
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
                
                // Use our improved seekToBeat method
                // We don't need to worry about playback state here since we're not playing yet
                seekToBeat(start)
            }
            
            // Start playback
            isPlaying = true
            startPlaybackTimer()
        } else {
            // Stop playback
            isPlaying = false
            stopPlaybackTimer()
        }
    }
    
    // Rewind to beginning
    func rewind() {
        // Store the current playback state
        let wasPlaying = isPlaying
        
        // If currently playing, stop playback first
        if wasPlaying {
            stopPlaybackTimer()
        }
        
        // Reset position to beginning
        currentBeat = 0.0
        internalBeatPosition = 0.0
        
        // If it was playing before, restart playback from the beginning
        if wasPlaying {
            startPlaybackTimer()
        }
    }
    
    // Seek to a specific beat position
    func seekToBeat(_ beat: Double) {
        // Store the current playback state
        let wasPlaying = isPlaying
        
        // If currently playing, stop the playback timer temporarily
        if wasPlaying {
            stopPlaybackTimer()
        }
        
        // Ensure beat is not negative
        let targetBeat = max(0, beat)
        
        // Update both the visible position and the internal position tracker
        currentBeat = targetBeat
        internalBeatPosition = targetBeat
        
        // If it was playing before, restart playback from the new position
        if wasPlaying {
            startPlaybackTimer()
        }
        
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
        
        // Update the timeline content width
        updateTimelineContentWidth()
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
        
        // Update the timeline content width
        updateTimelineContentWidth()
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
        
        // Update the timeline content width if needed
        updateTimelineContentWidth()
    }
    
    // MARK: - Private
    
    private var playbackTimer: Timer?
    private var internalBeatPosition: Double = 0.0
    private var lastUIUpdateTime: Date = Date()
    
    private func startPlaybackTimer() {
        // Make sure isPlaying is set to true
        isPlaying = true
        
        // Store the current beat position in our internal tracker
        internalBeatPosition = currentBeat
        lastUIUpdateTime = Date()
        
        // Get the timer frequency from the performance mode
        let timerFrequency = performanceMode.playbackTimerFrequency
        let updateFrequency = performanceMode.uiUpdateFrequency
        
        // Use a high precision timer for internal beat tracking
        // but limit UI updates based on performance mode
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 1/timerFrequency, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Calculate how much to increment based on tempo
            let beatsPerSecond = self.tempo / 60.0
            let increment = beatsPerSecond / timerFrequency
            
            // Update internal position always for accurate timing
            self.internalBeatPosition += increment
            
            // Only update the UI at the rate specified by the performance mode
            let now = Date()
            if now.timeIntervalSince(self.lastUIUpdateTime) >= 1/updateFrequency {
                // Simple update strategy - always update but at different rates
                // Check if we should use a reduced update rate
                let shouldUseReducedRate = self.findTimelineState()?.isScrolling == true
                
                // Use a reduced update rate during scrolling
                if shouldUseReducedRate {
                    if now.timeIntervalSince(self.lastUIUpdateTime) >= 1/10.0 {
                        self.currentBeat = self.internalBeatPosition
                        self.lastUIUpdateTime = now
                    }
                } else {
                    // Normal update when not scrolling
                    self.currentBeat = self.internalBeatPosition
                    self.lastUIUpdateTime = now
                }
            }
        }
    }
    
    private func stopPlaybackTimer() {
        // Stop the timer
        playbackTimer?.invalidate()
        playbackTimer = nil
        
        // Make sure isPlaying is set to false
        isPlaying = false
        
        // Ensure the published position matches our internal position
        currentBeat = internalBeatPosition
    }
    
    // Helper method to find the TimelineState if it exists
    private func findTimelineState() -> TimelineStateViewModel? {
        // Simply return the timelineState property
        // This is now properly set in TimelineView's onAppear
        return timelineState
    }
    
    // Update the timeline content width based on current tracks and clips
    private func updateTimelineContentWidth() {
        // Only update if we have a reference to the timeline state
        guard let timelineState = findTimelineState() else { 
            print("⚠️ PROJECT VM: Cannot update timeline width - no timeline state reference")
            return 
        }
        
        print("📏 PROJECT VM: Updating timeline content width based on current tracks and clips")
        
        // Force a UI update by triggering a small change in the zoom level
        // This will cause the timeline to recalculate its content width
        let currentZoom = timelineState.zoomLevel
        
        // Apply a small change to trigger recalculation
        DispatchQueue.main.async {
            timelineState.zoomLevel = currentZoom + 0.001
            
            // Reset to original zoom level after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                timelineState.zoomLevel = currentZoom
                print("📏 PROJECT VM: Timeline content width updated")
            }
        }
    }
} 
