import SwiftUI
import Combine

/// ViewModel for managing state and operations for a single track
class TrackViewModel: ObservableObject, Identifiable {
    // Unique identifier to match with the track
    var id: UUID { track.id }
    
    // Reference to the original track
    let track: Track
    
    // Reference to the project view model
    weak var projectViewModel: ProjectViewModel?
    
    // Published state properties - these drive the UI
    @Published var isEnabled: Bool
    @Published var isMuted: Bool
    @Published var isSolo: Bool
    @Published var isArmed: Bool
    @Published var customColor: Color?
    @Published var trackName: String
    @Published var volume: Double
    @Published var pan: Double
    @Published var isCollapsed: Bool
    
    // UI state for popups
    @Published var showingColorPicker: Bool = false
    @Published var showingDeleteConfirmation: Bool = false
    @Published var isEditingName: Bool = false
    
    // Cancellable for tracking subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    init(track: Track, projectViewModel: ProjectViewModel) {
        self.track = track
        self.projectViewModel = projectViewModel
        
        // Initialize state from track
        self.isEnabled = track.isEnabled
        self.isMuted = track.isMuted
        self.isSolo = track.isSolo
        self.isArmed = track.isArmed
        self.customColor = track.customColor
        self.trackName = track.name
        self.volume = track.volume
        self.pan = track.pan
        self.isCollapsed = track.isCollapsed
        
        // Listen for changes to the tracks array to update our local state
        setupTracksObserver()
    }
    
    // Set up observation of the tracks array to update local state
    private func setupTracksObserver() {
        guard let projectViewModel = projectViewModel else { return }
        
        projectViewModel.$tracks
            .sink { [weak self] tracks in
                guard let self = self,
                      let updatedTrack = tracks.first(where: { $0.id == self.track.id }) else {
                    return
                }
                
                // Update local state from the track in the array
                self.isEnabled = updatedTrack.isEnabled
                self.isMuted = updatedTrack.isMuted
                self.isSolo = updatedTrack.isSolo
                self.isArmed = updatedTrack.isArmed
                self.customColor = updatedTrack.customColor
                self.trackName = updatedTrack.name
                self.volume = updatedTrack.volume
                self.pan = updatedTrack.pan
                self.isCollapsed = updatedTrack.isCollapsed
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Computed Properties
    
    // Get the effective color for the track (custom color or default type color)
    var effectiveColor: Color {
        return customColor ?? track.type.color
    }
    
    // Get the effective background color based on the theme
    func effectiveBackgroundColor(for theme: ThemeOption) -> Color {
        let baseColor = effectiveColor
        
        switch theme {
        case .light:
            return baseColor.opacity(0.35)
        case .lightGrey:
            return baseColor.opacity(0.32)
        case .dark:
            return baseColor.opacity(0.3)
        case .black:
            return baseColor.opacity(0.25)
        }
    }
    
    // Formatted text for pan position display
    var panPositionText: String {
        if abs(pan - 0.5) < 0.01 {
            return "C"
        } else if pan < 0.5 {
            let leftPercentage = Int((0.5 - pan) * 200)
            return "L\(leftPercentage)%"
        } else {
            let rightPercentage = Int((pan - 0.5) * 200)
            return "R\(rightPercentage)%"
        }
    }
    
    // MARK: - Track Control Actions
    
    func toggleEnabled() {
        isEnabled.toggle()
        updateTrackControlsOnly()
    }
    
    func toggleMute() {
        isMuted.toggle()
        updateTrackControlsOnly()
    }
    
    func toggleSolo() {
        // Toggle the solo state - if it's currently off, turn it on (and vice versa)
        isSolo.toggle()
        
        // The ProjectViewModel.updateTrackControlsOnly method will handle the mutual exclusivity
        // It will turn off any other soloed tracks when turning this one on
        updateTrackControlsOnly()
    }
    
    func toggleArmed() {
        isArmed.toggle()
        updateTrackControlsOnly()
    }
    
    func toggleCollapsed() {
        isCollapsed.toggle()
        if let index = getTrackIndex() {
            projectViewModel?.updateTrackCollapsedStateOnly(at: index, isCollapsed: isCollapsed)
        }
    }
    
    func updateTrackName() {
        if let index = getTrackIndex() {
            projectViewModel?.updateTrackNameOnly(at: index, name: trackName)
        }
    }
    
    func updateTrackColor(_ color: Color?) {
        // Update our local customColor first to ensure immediate UI updates
        customColor = color
        
        // Then update the track in the project model
        if let index = getTrackIndex() {
            projectViewModel?.updateTrackColorOnly(at: index, color: color)
        }
    }
    
    func updateTrackVolume() {
        if let index = getTrackIndex() {
            projectViewModel?.updateTrackVolumeOnly(at: index, volume: volume)
        }
    }
    
    func updateTrackPan() {
        if let index = getTrackIndex() {
            projectViewModel?.updateTrackPanOnly(at: index, pan: pan)
        }
    }
    
    func deleteTrack() {
        if let index = getTrackIndex() {
            projectViewModel?.removeTrack(at: index)
        }
    }
    
    // MARK: - Helper Methods
    
    // Get the index of this track in the project's tracks array
    private func getTrackIndex() -> Int? {
        return projectViewModel?.tracks.firstIndex(where: { $0.id == track.id })
    }
    
    // Update all track control properties in one call
    func updateTrackControlsOnly() {
        if let index = getTrackIndex() {
            projectViewModel?.updateTrackControlsOnly(
                at: index,
                isMuted: isMuted,
                isSolo: isSolo,
                isArmed: isArmed,
                isEnabled: isEnabled
            )
        }
    }
    
    // Update all track properties in one call
    func updateTrack() {
        if let index = getTrackIndex(), let projectViewModel = projectViewModel {
            // Create an updated track with the current state
            var updatedTrack = track
            updatedTrack.isMuted = isMuted
            updatedTrack.isSolo = isSolo
            updatedTrack.isArmed = isArmed
            updatedTrack.isEnabled = isEnabled
            updatedTrack.name = trackName
            updatedTrack.volume = volume
            updatedTrack.pan = pan
            updatedTrack.customColor = customColor
            
            // Update the track in the view model
            projectViewModel.updateTrack(at: index, with: updatedTrack)
        }
    }
}
