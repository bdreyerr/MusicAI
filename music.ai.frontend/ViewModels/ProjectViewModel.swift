import SwiftUI
import Combine

/// Manager class to store and provide TrackViewModel instances
class TrackViewModelManager {
    // Dictionary to store track view models by track ID
    private var trackViewModels: [UUID: TrackViewModel] = [:]
    
    // Reference to the project view model
    private weak var projectViewModel: ProjectViewModel?
    
    init(projectViewModel: ProjectViewModel) {
        self.projectViewModel = projectViewModel
    }
    
    /// Get a TrackViewModel for a track, creating a new one if needed
    func viewModel(for track: Track) -> TrackViewModel {
        if let existing = trackViewModels[track.id] {
            return existing
        }
        
        // Create a new view model if none exists
        guard let projectViewModel = projectViewModel else {
            fatalError("ProjectViewModel is nil in TrackViewModelManager")
        }
        
        let newViewModel = TrackViewModel(track: track, projectViewModel: projectViewModel)
        trackViewModels[track.id] = newViewModel
        return newViewModel
    }
    
    /// Remove a track view model
    func removeViewModel(for trackId: UUID) {
        trackViewModels.removeValue(forKey: trackId)
    }
    
    /// Clear all track view models
    func clearViewModels() {
        trackViewModels.removeAll()
    }
}

class ProjectViewModel: ObservableObject {
    @Published var tempo: Double = 120.0
    @Published var timeSignatureBeats: Int = 4
    @Published var timeSignatureUnit: Int = 4
    @Published var isPlaying: Bool = false
    @Published var currentBeat: Double = 0.0 // Current playback position in beats
    @Published var tracks: [Track] = Track.samples
    @Published var selectedTrackId: UUID? = nil // ID of the currently selected track
    @Published var masterTrack: Track // Master track for final output processing
    
    // Performance optimization settings
    @Published var performanceMode: PerformanceMode = .balanced
    
    // Reference to the timeline state
    var timelineState: TimelineStateViewModel? = nil
    
    // Interaction manager for coordinating gestures and events
    let interactionManager = InteractionManager()
    
    // Track view model manager for providing track-specific view models
    lazy var trackViewModelManager: TrackViewModelManager = {
        return TrackViewModelManager(projectViewModel: self)
    }()
    
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
        // Initialize master track
        self.masterTrack = Track(name: "Master", type: .master)
        self.masterTrack.height = 100 // Set default height
        
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
        if selectedTrackId == masterTrack.id {
            return masterTrack
        }
        return tracks.first { $0.id == selectedTrackId }
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
        // Use DispatchQueue.main.async to prevent "modifying state during view update" errors
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Store the current playback state
            let wasPlaying = self.isPlaying
            
            // Only stop the playback timer if we are NOT already playing
            // This ensures we don't interrupt audio playback unnecessarily
            if wasPlaying {
                // Instead of stopping and restarting, just update position variables
                // Don't call stopPlaybackTimer() here - it would stop playback
                
                // Ensure beat is not negative
                let targetBeat = max(0, beat)
                
                // Update both the visible position and the internal position tracker
                self.currentBeat = targetBeat
                self.internalBeatPosition = targetBeat
                
                // In a real app, you would also update the audio engine's playback position here
                // For example: audioEngine.seekToPosition(currentBeat)
            } else {
                // If not playing, just update the position directly
                
                // Ensure beat is not negative
                let targetBeat = max(0, beat)
                
                // Update both the visible position and the internal position tracker
                self.currentBeat = targetBeat
                self.internalBeatPosition = targetBeat
                
                // In a real app, you would also update the audio engine's playback position here
                // For example: audioEngine.seekToPosition(currentBeat)
            }
        }
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
    func addTrack(name: String, type: TrackType, height: CGFloat = 100, afterIndex: Int? = nil) {
        var newTrack = Track(name: name, type: type)
        newTrack.height = height
        
        // print("📝 PROJECT VM: Adding new \(type) track: \(name)")
        // print("📝 PROJECT VM: Current track count: \(tracks.count)")
        // print("📝 PROJECT VM: afterIndex parameter: \(String(describing: afterIndex))")
        
        // Use withAnimation to make the track addition smoother
        withAnimation(.easeInOut(duration: 0.2)) {
            if let afterIndex = afterIndex, afterIndex >= 0 && afterIndex < tracks.count {
                // Insert after the specified index if provided and valid
                // print("📝 PROJECT VM: Inserting track at index \(afterIndex + 1)")
                tracks.insert(newTrack, at: afterIndex + 1)
            } else {
                // Otherwise append to the end
                // print("📝 PROJECT VM: Appending track to the end")
                tracks.append(newTrack)
            }
        }
        
        // If this is the first track, select it automatically
        if tracks.count == 1 {
            selectedTrackId = newTrack.id
            print("📝 PROJECT VM: First track, selecting it automatically")
        }
        
        // Track was just added - update the timeline content width
        // This is done to ensure there's enough space for the new track
        updateTimelineContentWidth(reason: "track_addition")
        
        // Print tracks after adding to verify
        DispatchQueue.main.async {
            // print("📋 PROJECT VM: Track list after adding:")
            for (i, track) in self.tracks.enumerated() {
                print("  \(i): \(track.name) (ID: \(track.id.uuidString.prefix(8))...)")
            }
        }
    }
    
    // Remove a track at the specified index
    func removeTrack(at index: Int) {
        guard index >= 0 && index < tracks.count else {
            print("❌ PROJECT VM: Failed to remove track - index \(index) out of bounds")
            return
        }
        
        let trackToRemove = tracks[index]
        
        // Get the track ID before removing it
        let trackId = trackToRemove.id
        
        // Clean up the track view model
        trackViewModelManager.removeViewModel(for: trackId)
        
        // Use withAnimation for smoother track removal
        withAnimation(.easeInOut(duration: 0.2)) {
            tracks.remove(at: index)
        }
        
        // If the removed track was selected, select another track
        if selectedTrackId == trackId {
            if !tracks.isEmpty {
                // Select the track at the same index if possible, or the previous one
                let newIndex = min(index, tracks.count - 1)
                selectedTrackId = tracks[newIndex].id
            } else {
                // No tracks left, clear selection
                selectedTrackId = nil
            }
        }
        
        // Update the timeline content width
        updateTimelineContentWidth(reason: "track_removal")
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
        updateTimelineContentWidth(reason: "track_update")
    }
    
    // Update just the pan value for a track without recalculating timeline content width
    func updateTrackPanOnly(at index: Int, pan: Double) {
        guard index >= 0 && index < tracks.count else {
            print("❌ PROJECT VM: Failed to update track pan - index \(index) out of bounds")
            return
        }
        
        // Update just the pan value directly 
        tracks[index].pan = pan
        
        // Still notify observers but skip the timeline content width update
        // since pan changes don't affect the layout of the timeline
        objectWillChange.send()
    }
    
    // Update just the volume value for a track without recalculating timeline content width
    func updateTrackVolumeOnly(at index: Int, volume: Double) {
        guard index >= 0 && index < tracks.count else {
            print("❌ PROJECT VM: Failed to update track volume - index \(index) out of bounds")
            return
        }
        
        // Update just the volume value directly 
        tracks[index].volume = volume
        
        // Still notify observers but skip the timeline content width update
        // since volume changes don't affect the layout of the timeline
        objectWillChange.send()
    }
    
    // Update track controls without recalculating timeline content width
    func updateTrackControlsOnly(at index: Int, isMuted: Bool? = nil, isSolo: Bool? = nil, 
                               isArmed: Bool? = nil, isEnabled: Bool? = nil) {
        guard index >= 0 && index < tracks.count else {
            print("❌ PROJECT VM: Failed to update track controls - index \(index) out of bounds")
            return
        }
        
        // Only update the properties that were passed in (not nil)
        if let muted = isMuted {
            tracks[index].isMuted = muted
        }
        
        if let solo = isSolo {
            tracks[index].isSolo = solo
        }
        
        if let armed = isArmed {
            tracks[index].isArmed = armed
        }
        
        if let enabled = isEnabled {
            tracks[index].isEnabled = enabled
        }
        
        // Still notify observers but skip the timeline content width update
        // since control changes don't affect the layout of the timeline
        objectWillChange.send()
    }
    
    // Update just the track height without recalculating timeline content width
    func updateTrackHeightOnly(at index: Int, height: CGFloat) {
        guard index >= 0 && index < tracks.count else {
            print("❌ PROJECT VM: Failed to update track height - index \(index) out of bounds")
            return
        }
        
        // Update just the height value directly 
        tracks[index].height = height
        
        // Still notify observers but skip the timeline content width update
        // since height changes don't affect the horizontal layout of the timeline
        objectWillChange.send()
    }
    
    // Update just the track name without recalculating timeline content width
    func updateTrackNameOnly(at index: Int, name: String) {
        guard index >= 0 && index < tracks.count else {
            print("❌ PROJECT VM: Failed to update track name - index \(index) out of bounds")
            return
        }
        
        // Update just the name directly
        tracks[index].name = name
        
        // Still notify observers but skip the timeline content width update
        objectWillChange.send()
    }
    
    // Update just the track color without recalculating timeline content width
    func updateTrackColorOnly(at index: Int, color: Color?) {
        guard index >= 0 && index < tracks.count else {
            print("❌ PROJECT VM: Failed to update track color - index \(index) out of bounds")
            return
        }
        
        // Update just the color directly
        tracks[index].customColor = color
        
        // Still notify observers but skip the timeline content width update
        objectWillChange.send()
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
    private func updateTimelineContentWidth(reason: String? = nil) {
        // Only update if we have a reference to the timeline state
        guard let timelineState = findTimelineState() else { 
            print("⚠️ PROJECT VM: Cannot update timeline width - no timeline state reference")
            return 
        }
        
        // Create a less noisy log - only print when in debug mode
        #if DEBUG
        if let reason = reason {
            print("📏 Updating timeline width - reason: \(reason)")
        } else {
            print("📏 Updating timeline width")
        }
        #endif
        
        // Instead of manipulating zoom level twice, use contentSizeChanged to trigger a recalculation
        DispatchQueue.main.async {
            // Notify that the content size has changed
            timelineState.contentSizeChanged()
            
            // Only log in debug mode to reduce console noise
            #if DEBUG
            // No need for a second log message - reduces noise
            #endif
        }
    }
} 
