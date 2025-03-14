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
    var timelineState: TimelineState? = nil
    
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
    
    // MARK: - Effects Management
    
    // Add an effect to the selected track
    func addEffectToSelectedTrack(_ effect: Effect) {
        guard let trackId = selectedTrackId,
              let index = tracks.firstIndex(where: { $0.id == trackId }) else { return }
        
        var updatedTrack = tracks[index]
        updatedTrack.addEffect(effect)
        
        // Update the track in the array
        tracks[index] = updatedTrack
    }
    
    // Remove an effect from the selected track
    func removeEffectFromSelectedTrack(effectId: UUID) {
        guard let trackId = selectedTrackId,
              let index = tracks.firstIndex(where: { $0.id == trackId }) else { return }
        
        var updatedTrack = tracks[index]
        updatedTrack.removeEffect(id: effectId)
        
        // Update the track in the array
        tracks[index] = updatedTrack
    }
    
    // Update an effect on the selected track
    func updateEffectOnSelectedTrack(_ updatedEffect: Effect) {
        guard let trackId = selectedTrackId,
              let trackIndex = tracks.firstIndex(where: { $0.id == trackId }) else { return }
        
        var updatedTrack = tracks[trackIndex]
        
        // Find and update the effect
        if let effectIndex = updatedTrack.effects.firstIndex(where: { $0.id == updatedEffect.id }) {
            updatedTrack.effects[effectIndex] = updatedEffect
            
            // Update the track in the array
            tracks[trackIndex] = updatedTrack
        }
    }
    
    // Set the instrument for the selected track (only applicable for MIDI tracks)
    func setInstrumentForSelectedTrack(_ instrument: Effect?) {
        guard let trackId = selectedTrackId,
              let index = tracks.firstIndex(where: { $0.id == trackId }) else { return }
        
        var updatedTrack = tracks[index]
        updatedTrack.setInstrument(instrument)
        
        // Update the track in the array
        tracks[index] = updatedTrack
    }
    
    // Get compatible effect types for the selected track
    func compatibleEffectTypesForSelectedTrack() -> [EffectType] {
        guard let track = selectedTrack else { return [] }
        
        switch track.type {
        case .audio:
            return [.equalizer, .compressor, .reverb, .delay, .filter]
        case .midi:
            return [.arpeggiator, .chordTrigger, .instrument]
        case .instrument:
            return [.filter, .synthesizer, .reverb, .delay]
        }
    }
    
    // MARK: - MIDI Clip Management
    
    // Create a MIDI clip from the current selection
    func createMidiClipFromSelection() -> Bool {
        // Ensure there is an active selection
        guard let timelineState = findTimelineState(),
              timelineState.selectionActive,
              let trackId = timelineState.selectionTrackId,
              let trackIndex = tracks.firstIndex(where: { $0.id == trackId }) else {
            return false
        }
        
        // Get the selected track
        var track = tracks[trackIndex]
        
        // Ensure this is a MIDI track
        guard track.type == .midi else {
            return false
        }
        
        // Get the selection range
        let (startBeat, endBeat) = timelineState.normalizedSelectionRange
        let duration = endBeat - startBeat
        
        // Ensure the duration is valid
        guard duration > 0 else {
            return false
        }
        
        // Check if we can add a clip at this position (no overlaps)
        guard track.canAddMidiClip(startBeat: startBeat, duration: duration) else {
            return false
        }
        
        // Create a new MIDI clip
        let clipName = "Clip \(track.midiClips.count + 1)"
        let newClip = MidiClip.createEmpty(name: clipName, startBeat: startBeat, duration: duration)
        
        // Add the clip to the track
        track.addMidiClip(newClip)
        
        // Update the track in the view model
        tracks[trackIndex] = track
        
        // Clear the selection
        timelineState.clearSelection()
        
        return true
    }
    
    // Remove a MIDI clip from a track
    func removeMidiClip(trackId: UUID, clipId: UUID) -> Bool {
        guard let trackIndex = tracks.firstIndex(where: { $0.id == trackId }) else {
            return false
        }
        
        var track = tracks[trackIndex]
        
        // Ensure this is a MIDI track
        guard track.type == .midi else {
            return false
        }
        
        // Remove the clip
        track.removeMidiClip(id: clipId)
        
        // Update the track in the view model
        tracks[trackIndex] = track
        
        return true
    }
    
    // Rename a MIDI clip
    func renameMidiClip(trackId: UUID, clipId: UUID, newName: String) -> Bool {
        guard !newName.isEmpty,
              let trackIndex = tracks.firstIndex(where: { $0.id == trackId }) else {
            return false
        }
        
        var track = tracks[trackIndex]
        
        // Ensure this is a MIDI track
        guard track.type == .midi else {
            return false
        }
        
        // Find the clip in the track
        guard let clipIndex = track.midiClips.firstIndex(where: { $0.id == clipId }) else {
            return false
        }
        
        // Update the clip name
        var updatedClip = track.midiClips[clipIndex]
        updatedClip.name = newName
        track.midiClips[clipIndex] = updatedClip
        
        // Update the track in the view model
        tracks[trackIndex] = track
        
        return true
    }
    
    // Get all MIDI clips for a specific track
    func midiClipsForTrack(trackId: UUID) -> [MidiClip] {
        guard let track = tracks.first(where: { $0.id == trackId }),
              track.type == .midi else {
            return []
        }
        
        return track.midiClips
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
    private func findTimelineState() -> TimelineState? {
        // Simply return the timelineState property
        // This is now properly set in TimelineView's onAppear
        return timelineState
    }
} 