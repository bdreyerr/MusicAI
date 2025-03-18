import SwiftUI
import AppKit

/// View for the controls section of a track in the timeline
struct TrackControlsView: View {
    let track: Track
    @ObservedObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    // State to track local changes before updating the model
    @State private var isMuted: Bool
    @State private var isSolo: Bool
    @State private var isArmed: Bool
    @State private var isEnabled: Bool
    @State private var trackName: String
    @State private var volume: Double
    @State private var pan: Double
    @State private var customColor: Color?
    
    // State for editing track name
    @State private var isEditingName: Bool = false
    
    // State for showing color picker
    @State private var showingColorPicker: Bool = false
    
    // State for showing delete confirmation
    @State private var showingDeleteConfirmation: Bool = false
    
    // State for resize handle
    @State private var isHoveringResizeHandle: Bool = false
    @State private var isDraggingResize: Bool = false
    @State private var resizePreviewHeight: CGFloat? = nil
    @State private var currentHeight: CGFloat
    
    // Initialize with track's current state
    init(track: Track, projectViewModel: ProjectViewModel) {
        self.track = track
        self.projectViewModel = projectViewModel
        
        // Initialize state from track
        _isMuted = State(initialValue: track.isMuted)
        _isSolo = State(initialValue: track.isSolo)
        _isArmed = State(initialValue: track.isArmed)
        _isEnabled = State(initialValue: track.isEnabled)
        _trackName = State(initialValue: track.name)
        _volume = State(initialValue: track.volume)
        _pan = State(initialValue: track.pan)
        _customColor = State(initialValue: track.customColor)
        _currentHeight = State(initialValue: track.height)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main track controls row
            
            // Track controls row - aligned at the top
            VStack(spacing: 2) {
                // Track icon and name
                HStack(spacing: 6) {
                    // Track icon with color
                    Image(systemName: track.type.icon)
                        .foregroundColor(themeManager.primaryTextColor)
                        .onTapGesture {
                            showingColorPicker.toggle()
                        }
                        .popover(isPresented: $showingColorPicker) {
                            VStack(spacing: 10) {
                                Text("Track Color")
                                    .font(.headline)
                                    .padding(.top, 8)
                                
                                ColorPicker("Select Color", selection: Binding(
                                    get: { customColor ?? track.type.color },
                                    set: { newColor in
                                        customColor = newColor
                                        updateTrackColor(newColor)
                                    }
                                ))
                                .padding(.horizontal)
                                
                                Button("Reset to Default") {
                                    customColor = nil
                                    updateTrackColor(nil)
                                    showingColorPicker = false
                                }
                                .padding(.bottom, 8)
                            }
                            .frame(width: 250)
                            .padding(8)
                        }
                        .help("Change track color")
                    
                    // Track name (editable)
                    if isEditingName {
                        TextField("Track name", text: $trackName, onCommit: {
                            isEditingName = false
                            updateTrackName()
                        })
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 120)
                        .onExitCommand {
                            isEditingName = false
                            updateTrackName()
                        }
                    } else {
                        Text(trackName)
                            .font(.subheadline)
                            .foregroundColor(themeManager.primaryTextColor)
                            .lineLimit(1)
                            .onTapGesture(count: 2) {
                                isEditingName = true
                            }
                            .help("Double-click to rename")
                    }
                    Spacer()
                }
                .padding(.leading, 8)
                .padding(.top, 4)
                
                HStack {
                    // Track controls
                    HStack(spacing: 8) {
                        // Enable/Disable toggle
                        Button(action: {
                            isEnabled.toggle()
                            updateTrackEnabledState()
                        }) {
                            Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(isEnabled ? .green : themeManager.primaryTextColor)
                                .font(.system(size: 12))
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .help(isEnabled ? "Disable Track" : "Enable Track")
                        
                        // Mute button
                        Button(action: {
                            isMuted.toggle()
                            updateTrackMuteState()
                        }) {
                            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2")
                                .foregroundColor(isMuted ? .red : themeManager.primaryTextColor)
                                .font(.system(size: 12))
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .help("Mute Track")
                        
                        // Solo button
                        Button(action: {
                            isSolo.toggle()
                            updateTrackSoloState()
                        }) {
                            Image(systemName: isSolo ? "s.square.fill" : "s.square")
                                .font(.system(size: 12))
                                .foregroundColor(isSolo ? .yellow : themeManager.primaryTextColor)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .help("Solo Track")
                        
                        // Record arm button
                        Button(action: {
                            isArmed.toggle()
                            updateTrackArmedState()
                        }) {
                            Image(systemName: "record.circle")
                                .font(.system(size: 12))
                                .foregroundColor(isArmed ? .red : themeManager.primaryTextColor)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .help("Arm Track for Recording")
                        
                        // Delete track button
                        Button(action: {
                            showingDeleteConfirmation = true
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                                .foregroundColor(themeManager.primaryTextColor)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .help("Delete Track")
                        .alert(isPresented: $showingDeleteConfirmation) {
                            Alert(
                                title: Text("Delete Track"),
                                message: Text("Are you sure you want to delete '\(trackName)'? This cannot be undone."),
                                primaryButton: .destructive(Text("Delete")) {
                                    deleteTrack()
                                },
                                secondaryButton: .cancel()
                            )
                        }
                    }
                    .padding(.trailing, 8)
                    Spacer()
                }
                .padding(.leading, 8)
                .padding(.bottom, 1)
            }
            .frame(maxWidth: .infinity)
            
//            Spacer()
            
            // Volume slider section
            HStack(spacing: 8) {
                Image(systemName: "speaker.wave.1")
                    .foregroundColor(themeManager.primaryTextColor)
                    .font(.caption)
                
                Slider(value: $volume, in: 0...1) { editing in
                    if !editing {
                        updateTrackVolume()
                    }
                }
                .frame(height: 16)
                
                Text("\(Int(volume * 100))%")
                    .font(.caption)
                    .foregroundColor(themeManager.primaryTextColor)
                    .frame(width: 32, alignment: .trailing)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            
            // Pan control section
            HStack(spacing: 8) {
                Text("L")
                    .font(.caption)
                    .foregroundColor(themeManager.primaryTextColor)
                
                // Pan slider with center indicator
                ZStack(alignment: .center) {
                    // Pan slider - only update on completion to reduce timeline redraws
                    Slider(value: $pan, in: 0...1) { editing in
                        // Only update the model when editing is complete
                        if !editing {
                            updateTrackPan()
                        }
                    }
                    .accentColor(track.effectiveColor)
                    .frame(height: 16)
                    
                    // Center line indicator
                    Rectangle()
                        .fill(themeManager.primaryTextColor.opacity(0.5))
                        .frame(width: 1, height: 12)
                }
                // Double-click to reset to center
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    // Reset to center (0.5)
                    pan = 0.5
                    updateTrackPan()
                }
                
                Text("R")
                    .font(.caption)
                    .foregroundColor(themeManager.primaryTextColor)
                
                // Pan position indicator text
                Text(panPositionText)
                    .font(.caption)
                    .foregroundColor(themeManager.primaryTextColor)
                    .frame(width: 32, alignment: .trailing)
            }
            .padding(.horizontal, 8)
            .padding(.top, 2)
            .padding(.bottom, 3)
        }
        .frame(height: track.height)
        .frame(minHeight: 40)
        .background(track.effectiveBackgroundColor(for: themeManager.currentTheme))
        // Add a selection highlight for the entire control area
        .overlay(
            ZStack {
                // Regular border for all tracks
                Rectangle()
                    .stroke(themeManager.secondaryBorderColor, lineWidth: 0.5)
                    .allowsHitTesting(false)
                
                // Selection highlight for the entire control area
                if projectViewModel.isTrackSelected(track) {
                    Rectangle()
                        .fill(themeManager.accentColor.opacity(0.15))
                        .brightness(0.1)
                        .allowsHitTesting(false)
                    
                    // Selection border
                    Rectangle()
                        .stroke(themeManager.accentColor.opacity(0.9), lineWidth: 1.5)
                        .brightness(0.3)
                        .allowsHitTesting(false)
                }
            }
        )
        .opacity(isEnabled ? 1.0 : 0.7) // Dim the controls if track is disabled
        // Make the track controls selectable with a tap
        .onTapGesture {
            projectViewModel.selectTrack(id: track.id)
            // We don't need to seek to the current beat position here
            // This was interrupting playback unnecessarily
        }
        .overlay(
            // Resize handle at the bottom
            Rectangle()
                .fill(Color.clear)
                .frame(height: 8)
                .frame(maxWidth: .infinity)
                .background(
                    isHoveringResizeHandle ?
                    track.effectiveColor.opacity(0.5) :
                        Color.clear
                )
                .onHover { hovering in
                    isHoveringResizeHandle = hovering
                    if hovering {
                        NSCursor.resizeUpDown.set()
                    } else if !isDraggingResize {
                        NSCursor.arrow.set()
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            if !isDraggingResize {
                                isDraggingResize = true
                                NSCursor.resizeUpDown.set()
                            }
                            
                            // Just store the preview height - don't change real height during drag
                            let baseHeight = track.height
                            resizePreviewHeight = max(90, baseHeight + value.translation.height)
                        }
                        .onEnded { _ in
                            isDraggingResize = false
                            if !isHoveringResizeHandle {
                                NSCursor.arrow.set()
                            }
                            
                            // Only update if we have a preview height and it differs from current
                            if let previewHeight = resizePreviewHeight, abs(previewHeight - track.height) > 1 {
                                // Update model once at the end
                                updateTrackHeight(previewHeight)
                                // Keep local state in sync with what we set
                                currentHeight = previewHeight
                            }
                            
                            // Clear the preview
                            resizePreviewHeight = nil
                        }
                )
                .help("Resize track height")
            , alignment: .bottom
        )
        // Add resize preview indicator overlay at highest z-index
        .overlay(
            Group {
                if isDraggingResize, let previewHeight = resizePreviewHeight {
                    // Visual indicator showing where the height will be
                    GeometryReader { geo in
                        VStack {
                            Spacer()
                            Rectangle()
                                .fill(themeManager.accentColor)
                                .frame(height: 2)
                                .offset(y: previewHeight - track.height)
                                .opacity(0.7)
                        }
                    }
                }
            }
        )
    }
    
    // Update the track in the project view model
    private func updateTrack() {
        // Find the track in the view model's tracks array
        if let index = projectViewModel.tracks.firstIndex(where: { $0.id == track.id }) {
            // Create an updated track with the new state
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
    
    // Update just the track name
    private func updateTrackName() {
        if let index = projectViewModel.tracks.firstIndex(where: { $0.id == track.id }) {
            // Update the name directly without recalculating timeline width
            projectViewModel.updateTrackNameOnly(at: index, name: trackName)
        }
    }
    
    // Update just the track color
    private func updateTrackColor(_ color: Color?) {
        if let index = projectViewModel.tracks.firstIndex(where: { $0.id == track.id }) {
            // Update the color directly without recalculating timeline width
            projectViewModel.updateTrackColorOnly(at: index, color: color)
        }
    }
    
    // Update just the track volume
    private func updateTrackVolume() {
        if let index = projectViewModel.tracks.firstIndex(where: { $0.id == track.id }) {
            // Update the volume directly without recalculating timeline width
            projectViewModel.updateTrackVolumeOnly(at: index, volume: volume)
        }
    }
    
    // Update just the track pan
    private func updateTrackPan() {
        if let index = projectViewModel.tracks.firstIndex(where: { $0.id == track.id }) {
            var updatedTrack = track
            updatedTrack.pan = pan
            
            // Update the track in the view model but skip timeline width recalculation
            // since pan changes don't affect the timeline content width
            projectViewModel.updateTrackPanOnly(at: index, pan: pan)
        }
    }
    
    // Computed property for pan position text (used for detailed display)
    private var panPositionText: String {
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
    
    // Update just the track height
    private func updateTrackHeight(_ newHeight: CGFloat) {
        if let index = projectViewModel.tracks.firstIndex(where: { $0.id == track.id }) {
            // Update the height directly without recalculating timeline width
            projectViewModel.updateTrackHeightOnly(at: index, height: newHeight)
        }
    }
    
    // Delete the track
    private func deleteTrack() {
        if let index = projectViewModel.tracks.firstIndex(where: { $0.id == track.id }) {
            projectViewModel.removeTrack(at: index)
        }
    }
    
    // Update track enabled state
    private func updateTrackEnabledState() {
        if let index = projectViewModel.tracks.firstIndex(where: { $0.id == track.id }) {
            projectViewModel.updateTrackControlsOnly(at: index, isEnabled: isEnabled)
        }
    }
    
    // Update track mute state
    private func updateTrackMuteState() {
        if let index = projectViewModel.tracks.firstIndex(where: { $0.id == track.id }) {
            projectViewModel.updateTrackControlsOnly(at: index, isMuted: isMuted)
        }
    }
    
    // Update track solo state
    private func updateTrackSoloState() {
        if let index = projectViewModel.tracks.firstIndex(where: { $0.id == track.id }) {
            projectViewModel.updateTrackControlsOnly(at: index, isSolo: isSolo)
        }
    }
    
    // Update track armed state
    private func updateTrackArmedState() {
        if let index = projectViewModel.tracks.firstIndex(where: { $0.id == track.id }) {
            projectViewModel.updateTrackControlsOnly(at: index, isArmed: isArmed)
        }
    }
}

#Preview {
    TrackControlsView(
        track: Track.samples[0],
        projectViewModel: ProjectViewModel()
    )
    .environmentObject(ThemeManager())
    .frame(width: 200)
}
