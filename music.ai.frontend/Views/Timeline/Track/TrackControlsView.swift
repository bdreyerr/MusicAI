import SwiftUI
import AppKit

/// View for the controls section of a track in the timeline
struct TrackControlsView: View {
    let track: Track
    @ObservedObject var projectViewModel: ProjectViewModel
    @ObservedObject var trackViewModel: TrackViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var menuCoordinator: MenuCoordinator
    
    // State for resize handle
    @State private var isHoveringResizeHandle: Bool = false
    @State private var isDraggingResize: Bool = false
    @State private var resizePreviewHeight: CGFloat? = nil
    @State private var currentHeight: CGFloat
    
    // Initialize with track's current state
    init(track: Track, projectViewModel: ProjectViewModel) {
        self.track = track
        self.projectViewModel = projectViewModel
        
        // Get the track view model from the manager
        self._trackViewModel = ObservedObject(wrappedValue: projectViewModel.trackViewModelManager.viewModel(for: track))
        
        // Initialize resize state from track
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
                            trackViewModel.showingColorPicker.toggle()
                        }
                        .popover(isPresented: $trackViewModel.showingColorPicker) {
                            VStack(spacing: 10) {
                                Text("Track Color")
                                    .font(.headline)
                                    .padding(.top, 8)
                                
                                ColorPicker("Select Color", selection: Binding(
                                    get: { trackViewModel.customColor ?? track.type.color },
                                    set: { newColor in
                                        trackViewModel.customColor = newColor
                                        updateTrackColor(newColor)
                                    }
                                ))
                                .padding(.horizontal)
                                
                                Button("Reset to Default") {
                                    trackViewModel.customColor = nil
                                    updateTrackColor(nil)
                                    trackViewModel.showingColorPicker = false
                                }
                                .padding(.bottom, 8)
                            }
                            .frame(width: 250)
                            .padding(8)
                        }
                        .help("Change track color")
                    
                    // Track name (editable)
                    if trackViewModel.isEditingName {
                        TextField("Track name", text: $trackViewModel.trackName, onCommit: {
                            trackViewModel.isEditingName = false
                            trackViewModel.updateTrackName()
                        })
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 120)
                        .onExitCommand {
                            trackViewModel.isEditingName = false
                            trackViewModel.updateTrackName()
                        }
                    } else {
                        Text(trackViewModel.trackName)
                            .font(.subheadline)
                            .foregroundColor(themeManager.primaryTextColor)
                            .lineLimit(1)
                            .onTapGesture(count: 2) {
                                trackViewModel.isEditingName = true
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
                            trackViewModel.toggleEnabled()
                        }) {
                            Image(systemName: trackViewModel.isEnabled ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(trackViewModel.isEnabled ? .green : themeManager.primaryTextColor)
                                .font(.system(size: 12))
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .help(trackViewModel.isEnabled ? "Disable Track" : "Enable Track")
                        
                        // Mute button
                        Button(action: {
                            trackViewModel.toggleMute()
                        }) {
                            Image(systemName: trackViewModel.isMuted ? "speaker.slash.fill" : "speaker.wave.2")
                                .foregroundColor(trackViewModel.isMuted ? .red : themeManager.primaryTextColor)
                                .font(.system(size: 12))
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .help("Mute Track")
                        
                        // Solo button
                        Button(action: {
                            trackViewModel.toggleSolo()
                        }) {
                            Image(systemName: trackViewModel.isSolo ? "s.square.fill" : "s.square")
                                .font(.system(size: 12))
                                .foregroundColor(trackViewModel.isSolo ? .yellow : themeManager.primaryTextColor)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .help("Solo Track")
                        
                        // Record arm button
                        Button(action: {
                            trackViewModel.toggleArmed()
                        }) {
                            Image(systemName: "record.circle")
                                .font(.system(size: 12))
                                .foregroundColor(trackViewModel.isArmed ? .red : themeManager.primaryTextColor)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .help("Arm Track for Recording")
                        
                        // Delete track button
                        Button(action: {
                            trackViewModel.showingDeleteConfirmation = true
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                                .foregroundColor(themeManager.primaryTextColor)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .help("Delete Track")
                        .alert(isPresented: $trackViewModel.showingDeleteConfirmation) {
                            Alert(
                                title: Text("Delete Track"),
                                message: Text("Are you sure you want to delete '\(trackViewModel.trackName)'? This cannot be undone."),
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
                
                Slider(value: $trackViewModel.volume, in: 0...1) { editing in
                    if !editing {
                        updateTrackVolume()
                    }
                }
                .frame(height: 16)
                
                Text("\(Int(trackViewModel.volume * 100))%")
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
                    Slider(value: $trackViewModel.pan, in: 0...1) { editing in
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
                    trackViewModel.pan = 0.5
                    updateTrackPan()
                }
                
                Text("R")
                    .font(.caption)
                    .foregroundColor(themeManager.primaryTextColor)
                
                // Pan position indicator text
                Text(trackViewModel.panPositionText)
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
        .contextMenu {
            trackControlsContextMenu
        }
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
        .opacity(trackViewModel.isEnabled ? 1.0 : 0.7) // Dim the controls if track is disabled
        // Make the track controls selectable with a tap
        .onTapGesture {
            projectViewModel.selectTrack(id: track.id)
            // We don't need to seek to the current beat position here
            // This was interrupting playback unnecessarily
        }
        .onAppear {
            // Update currentHeight whenever the view appears
            currentHeight = track.height
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
        // We can use trackViewModel to update all properties at once
        trackViewModel.updateTrackControlsOnly()
    }
    
    // Update just the track name
    private func updateTrackName() {
        trackViewModel.updateTrackName()
    }
    
    // Update just the track color
    private func updateTrackColor(_ color: Color?) {
        trackViewModel.updateTrackColor(color)
    }
    
    // Update just the track volume
    private func updateTrackVolume() {
        trackViewModel.updateTrackVolume()
    }
    
    // Update just the track pan
    private func updateTrackPan() {
        trackViewModel.updateTrackPan()
    }
    
    // Computed property for pan position text (used for detailed display)
    private var panPositionText: String {
        if abs(trackViewModel.pan - 0.5) < 0.01 {
            return "C"
        } else if trackViewModel.pan < 0.5 {
            let leftPercentage = Int((0.5 - trackViewModel.pan) * 200)
            return "L\(leftPercentage)%"
        } else {
            let rightPercentage = Int((trackViewModel.pan - 0.5) * 200)
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
        trackViewModel.deleteTrack()
    }
    
    // MARK: - Context Menu
    
    @ViewBuilder
    private var trackControlsContextMenu: some View {
        // Enable/Disable option
        Button(trackViewModel.isEnabled ? "Disable Track" : "Enable Track") {
            trackViewModel.toggleEnabled()
        }
        
        // Mute option
        Button(trackViewModel.isMuted ? "Unmute Track" : "Mute Track") {
            trackViewModel.toggleMute()
        }
        
        // Solo option
        Button(trackViewModel.isSolo ? "Unsolo Track" : "Solo Track") {
            trackViewModel.toggleSolo()
        }
        
        Divider()
        
        // Rename option
        Button("Rename Track") {
            // Show a popup to get the new name
            let alert = NSAlert()
            alert.messageText = "Rename Track"
            alert.informativeText = "Enter a new name for the track:"
            
            let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
            textField.stringValue = trackViewModel.trackName
            alert.accessoryView = textField
            
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                trackViewModel.trackName = textField.stringValue
                trackViewModel.updateTrackName()
            }
        }
        
        // Change color option
        Button("Change Color") {
            trackViewModel.showingColorPicker = true
        }
        
        // Delete option
        Button("Delete Track", role: .destructive) {
            trackViewModel.showingDeleteConfirmation = true
        }
        
        // TODO: Add back when we can copy and paste tracks
//        Button("Copy") {
//            menuCoordinator.copySelectedClip()
//        }
//        .keyboardShortcut("c", modifiers: .command)
//        
//        Button("Paste") {
//            menuCoordinator.pasteClip()
//        }
//        .keyboardShortcut("v", modifiers: .command)
        
        
    }
    
    // Update track enabled state
    private func updateTrackEnabledState() {
        trackViewModel.toggleEnabled()
    }
    
    // Update track mute state
    private func updateTrackMuteState() {
        trackViewModel.toggleMute()
    }
    
    // Update track solo state
    private func updateTrackSoloState() {
        trackViewModel.toggleSolo()
    }
    
    // Update track armed state
    private func updateTrackArmedState() {
        trackViewModel.toggleArmed()
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
