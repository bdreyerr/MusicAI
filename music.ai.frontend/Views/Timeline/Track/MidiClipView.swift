import SwiftUI
import AppKit

/// View for displaying a MIDI clip on a track
struct MidiClipView: View {
    let clip: MidiClip
    let track: Track
    @ObservedObject var state: TimelineStateViewModel
    @ObservedObject var projectViewModel: ProjectViewModel
    @ObservedObject var trackViewModel: TrackViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var menuCoordinator: MenuCoordinator
    
    // Computed property to access the MIDI view model
    private var midiViewModel: MidiViewModel {
        return projectViewModel.midiViewModel
    }
    
    // State for hover and selection
    @State private var isHovering: Bool = false
    @State private var isDragging: Bool = false
    @State private var isResizing: Bool = false
    @State private var isHoveringLeftResizeArea: Bool = false
    @State private var isHoveringRightResizeArea: Bool = false
    @State private var showRenameDialog: Bool = false
    @State private var newClipName: String = ""
    @State private var dragStartBeat: Double = 0 // Track the starting beat position for drag
    @State private var dragStartLocation: CGPoint = .zero // Track the starting location for drag
    @State private var resizeStartDuration: Double = 0 // Track the starting duration for resize
    @State private var resizeStartPosition: Double = 0 // Track the starting position for resize
    @State private var isResizingLeft: Bool = false // Track which side we're resizing from
    
    // Computed property to determine if resize handles should be visible
    private var showResizeHandles: Bool {
        return isHovering || isHoveringLeftResizeArea || isHoveringRightResizeArea || isDragging || isResizing
    }
    
    // Computed property to check if this clip is selected
    private var isSelected: Bool {
        guard state.selectionActive,
                projectViewModel.selectedTrackId == track.id else {
            return false
        }
        
        // Check if the selection range matches this clip's range
        let (selStart, selEnd) = state.normalizedSelectionRange
        return abs(selStart - clip.startBeat) < 0.001 &&
        abs(selEnd - clip.endBeat) < 0.001
    }
    
    // Initialize with constructor that takes trackViewModel
    init(clip: MidiClip, track: Track, state: TimelineStateViewModel, projectViewModel: ProjectViewModel, trackViewModel: TrackViewModel) {
        self.clip = clip
        self.track = track
        self.state = state
        self.projectViewModel = projectViewModel
        self.trackViewModel = trackViewModel
    }
    
    var body: some View {
        // Calculate position and size based on timeline state
        let startX = CGFloat(clip.startBeat * state.effectivePixelsPerBeat)
        let width = CGFloat(clip.duration * state.effectivePixelsPerBeat)
        let clipHeight = trackViewModel.isCollapsed ? 26 : track.height - 4 // Use fixed 26px for collapsed state
        
        // Use a ZStack to position the clip correctly
        ZStack(alignment: .topLeading) {
            // Empty view to take up the entire track width
            Color.clear
                .frame(width: width, height: clipHeight)
                .allowsHitTesting(false) // Don't block clicks
            
            // Clip background with content
            ZStack(alignment: .topLeading) {
                // Background
                RoundedRectangle(cornerRadius: trackViewModel.isCollapsed ? 3 : 4)
                    .fill(clip.color ?? track.effectiveColor)
                    .opacity(isSelected ? 0.9 : (isHovering ? 0.8 : 0.6))
                
                // Selection border
                RoundedRectangle(cornerRadius: trackViewModel.isCollapsed ? 3 : 4)
                    .stroke(Color.white, lineWidth: isSelected ? 2 : 0)
                    .opacity(isSelected ? 0.8 : 0)
                
                // Dragging indicator
                if isDragging {
                    RoundedRectangle(cornerRadius: trackViewModel.isCollapsed ? 3 : 4)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
                        .foregroundColor(.white)
                        .opacity(0.9)
                }
                
                // Resizing indicator
                if isResizing {
                    RoundedRectangle(cornerRadius: trackViewModel.isCollapsed ? 3 : 4)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [3, 3]))
                        .foregroundColor(.yellow)
                        .opacity(0.9)
                }
                
                // Clip name
                Text(clip.name)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(trackViewModel.isCollapsed ? 2 : 6)
                    .lineLimit(1)
                
                // Notes visualization (placeholder for now)
                if !trackViewModel.isCollapsed && clip.notes.isEmpty {
                    Text("Empty clip")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.top, 24)
                        .padding(.leading, 6)
                }
                
                // Add three distinct interaction regions: left resize, center drag, right resize
                HStack(spacing: 0) {
                    // Left resize handle
                    ZStack {
                        // Visual handle
                        Rectangle()
                            .fill(Color.white.opacity(isHoveringLeftResizeArea ? 0.5 : (showResizeHandles ? 0.2 : 0)))
                            .frame(width: trackViewModel.isCollapsed ? 6 : 10, height: clipHeight - 8)
                            .cornerRadius(2)
                    }
                    .frame(width: trackViewModel.isCollapsed ? 6 : 10, height: clipHeight)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        isHoveringLeftResizeArea = hovering
                        isHoveringRightResizeArea = false
                        isHovering = false
                        
                        if hovering {
                            NSCursor.resizeLeftRight.set()
                        } else if !isResizing && !isDragging {
                            NSCursor.arrow.set()
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                // If we're not already resizing, try to start
                                if !isResizing {
                                    // Ensure clip is selected
                                    if !isSelected {
                                        selectThisClip()
                                    }
                                    
                                    // Check if we can start a clip resize
                                    if !projectViewModel.interactionManager.canStartClipResize() {
                                        return
                                    }
                                    
                                    // Inform the interaction manager we're starting a resize
                                    if projectViewModel.interactionManager.startClipResize() {
                                        resizeStartDuration = clip.duration
                                        resizeStartPosition = clip.startBeat
                                        isResizing = true
                                        isResizingLeft = true
                                        NSCursor.resizeLeftRight.set()
                                    } else {
                                        return
                                    }
                                }
                                
                                // Calculate new position and duration for left resize
                                let dragDistanceInBeats = value.translation.width / CGFloat(state.effectivePixelsPerBeat)
                                var newStartBeat = resizeStartPosition + Double(dragDistanceInBeats)
                                
                                // Ensure we don't go past the end of the clip
                                let clipEnd = resizeStartPosition + resizeStartDuration
                                newStartBeat = min(newStartBeat, clipEnd - 0.25) // Ensure minimum duration
                                
                                // Ensure we don't go negative
                                newStartBeat = max(0, newStartBeat)
                                
                                // Snap to grid
                                let snappedStartBeat = snapToNearestGridMarker(newStartBeat)
                                
                                // Calculate new duration based on the snapped start position
                                let newDuration = (resizeStartPosition + resizeStartDuration) - snappedStartBeat
                                
                                // Preview the new selection size
                                state.startSelection(at: snappedStartBeat, trackId: track.id)
                                state.updateSelection(to: snappedStartBeat + newDuration)
                            }
                            .onEnded { value in
                                guard isResizing && isResizingLeft else { return }
                                
                                // Calculate new position and duration
                                let dragDistanceInBeats = value.translation.width / CGFloat(state.effectivePixelsPerBeat)
                                var newStartBeat = resizeStartPosition + Double(dragDistanceInBeats)
                                
                                // Ensure we don't go past the end of the clip
                                let clipEnd = resizeStartPosition + resizeStartDuration
                                newStartBeat = min(newStartBeat, clipEnd - 0.25) // Ensure minimum duration
                                
                                // Ensure we don't go negative
                                newStartBeat = max(0, newStartBeat)
                                
                                // Snap to grid
                                let snappedStartBeat = snapToNearestGridMarker(newStartBeat)
                                
                                // Calculate new duration
                                let newDuration = (resizeStartPosition + resizeStartDuration) - snappedStartBeat
                                
                                // Only apply if the position or duration actually changed
                                if abs(newStartBeat - clip.startBeat) > 0.001 || abs(newDuration - clip.duration) > 0.001 {
                                    // First move the clip to its new position
                                    let success1 = midiViewModel.moveMidiClip(
                                        trackId: track.id,
                                        clipId: clip.id,
                                        newStartBeat: snappedStartBeat
                                    )
                                    
                                    // Then resize it to its new duration
                                    let success2 = midiViewModel.resizeMidiClip(
                                        trackId: track.id,
                                        clipId: clip.id,
                                        newDuration: newDuration
                                    )
                                    
                                    if success1 && success2 {
                                        // Update selection to match new clip size
                                        state.startSelection(at: snappedStartBeat, trackId: track.id)
                                        state.updateSelection(to: snappedStartBeat + newDuration)
                                    } else {
                                        // Reset selection to original clip size
                                        state.startSelection(at: clip.startBeat, trackId: track.id)
                                        state.updateSelection(to: clip.endBeat)
                                    }
                                } else {
                                    // No change, just reset selection
                                    state.startSelection(at: clip.startBeat, trackId: track.id)
                                    state.updateSelection(to: clip.endBeat)
                                }
                                
                                // End the resize interaction
                                projectViewModel.interactionManager.endClipResize()
                                isResizing = false
                                isResizingLeft = false
                                
                                // Reset cursor if still hovering
                                if isHoveringLeftResizeArea {
                                    NSCursor.resizeLeftRight.set()
                                } else {
                                    NSCursor.arrow.set()
                                }
                            }
                    )
                    
                    // Main clip drag area in the center (takes all remaining space)
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: max(0, width - (trackViewModel.isCollapsed ? 12 : 20)), height: clipHeight)
                        .contentShape(Rectangle())
                        .onHover { hovering in
                            isHovering = hovering
                            isHoveringLeftResizeArea = false
                            isHoveringRightResizeArea = false
                            
                            if hovering && !isResizing && !isDragging {
                                if isSelected {
                                    NSCursor.openHand.set()
                                } else {
                                    NSCursor.pointingHand.set()
                                }
                            } else if !isResizing && !isDragging {
                                NSCursor.arrow.set()
                            }
                        }
                        .gesture(
                            DragGesture(minimumDistance: 3)
                                .onChanged { value in
                                    // Don't start drag if we're already resizing
                                    if isResizing {
                                        return
                                    }
                                    
                                    // If we're not already dragging, set up the drag operation
                                    if !isDragging {
                                        // If the clip isn't selected yet, select it first
                                        if !isSelected {
                                            selectThisClip()
                                        }
                                        
                                        // Check if we can start a clip drag
                                        if !projectViewModel.interactionManager.canStartClipDrag() {
                                            return
                                        }
                                        
                                        // Inform the interaction manager that we're starting a clip drag
                                        if projectViewModel.interactionManager.startClipDrag() {
                                            dragStartBeat = clip.startBeat
                                            dragStartLocation = value.startLocation
                                            isDragging = true
                                            NSCursor.closedHand.set()
                                        } else {
                                            return
                                        }
                                    }
                                    
                                    // Only update if we're actively dragging
                                    if isDragging {
                                        // Calculate the drag distance in beats directly from the translation
                                        let dragDistanceInBeats = value.translation.width / CGFloat(state.effectivePixelsPerBeat)
                                        
                                        // Calculate the new beat position
                                        let rawNewBeatPosition = dragStartBeat + Double(dragDistanceInBeats)
                                        
                                        // Snap to grid
                                        let snappedBeatPosition = snapToNearestGridMarker(rawNewBeatPosition)
                                        
                                        // Ensure we don't go negative
                                        let finalPosition = max(0, snappedBeatPosition)
                                        
                                        // Update the selection to preview the new position
                                        state.startSelection(at: finalPosition, trackId: track.id)
                                        state.updateSelection(to: finalPosition + clip.duration)
                                    }
                                }
                                .onEnded { value in
                                    // Only process if we were actually dragging
                                    guard isDragging else {
                                        return
                                    }
                                    
                                    // Calculate the final drag distance directly from the translation
                                    let dragDistanceInBeats = value.translation.width / CGFloat(state.effectivePixelsPerBeat)
                                    
                                    // Calculate the new beat position
                                    let rawNewBeatPosition = dragStartBeat + Double(dragDistanceInBeats)
                                    
                                    // Snap to grid
                                    let snappedBeatPosition = snapToNearestGridMarker(rawNewBeatPosition)
                                    
                                    // Ensure we don't go negative
                                    let finalPosition = max(0, snappedBeatPosition)
                                    
                                    // Only move if the position actually changed
                                    if abs(finalPosition - clip.startBeat) > 0.001 {
                                        // Move the clip to the new position using the MIDI view model
                                        let success = midiViewModel.moveMidiClip(
                                            trackId: track.id,
                                            clipId: clip.id,
                                            newStartBeat: finalPosition
                                        )
                                        
                                        if success {
                                            // Update the selection to match the new clip position
                                            state.startSelection(at: finalPosition, trackId: track.id)
                                            state.updateSelection(to: finalPosition + clip.duration)
                                        } else {
                                            // Reset the selection to the original clip position
                                            state.startSelection(at: clip.startBeat, trackId: track.id)
                                            state.updateSelection(to: clip.endBeat)
                                        }
                                    } else {
                                        // If position didn't change, reset selection to current clip position
                                        state.startSelection(at: clip.startBeat, trackId: track.id)
                                        state.updateSelection(to: clip.endBeat)
                                    }
                                    
                                    // Inform the interaction manager that we're done with the drag
                                    projectViewModel.interactionManager.endClipDrag()
                                    
                                    // Reset drag state
                                    isDragging = false
                                    dragStartLocation = .zero
                                    
                                    // Reset cursor based on hover state
                                    if isHovering {
                                        NSCursor.openHand.set()
                                    } else {
                                        NSCursor.arrow.set()
                                    }
                                }
                        )
                        .onTapGesture {
                            selectThisClip()
                        }
                    
                    // Right resize handle
                    ZStack {
                        // Visual handle
                        Rectangle()
                            .fill(Color.white.opacity(isHoveringRightResizeArea ? 0.5 : (showResizeHandles ? 0.2 : 0)))
                            .frame(width: trackViewModel.isCollapsed ? 6 : 10, height: clipHeight - 8)
                            .cornerRadius(2)
                    }
                    .frame(width: trackViewModel.isCollapsed ? 6 : 10, height: clipHeight)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        isHoveringRightResizeArea = hovering
                        isHoveringLeftResizeArea = false
                        isHovering = false
                        
                        if hovering {
                            NSCursor.resizeLeftRight.set()
                        } else if !isResizing && !isDragging {
                            NSCursor.arrow.set()
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                // If we're not already resizing, try to start
                                if !isResizing {
                                    // Ensure clip is selected
                                    if !isSelected {
                                        selectThisClip()
                                    }
                                    
                                    // Check if we can start a clip resize
                                    if !projectViewModel.interactionManager.canStartClipResize() {
                                        return
                                    }
                                    
                                    // Inform the interaction manager we're starting a resize
                                    if projectViewModel.interactionManager.startClipResize() {
                                        resizeStartDuration = clip.duration
                                        isResizing = true
                                        isResizingLeft = false
                                        NSCursor.resizeLeftRight.set()
                                    } else {
                                        return
                                    }
                                }
                                
                                // Calculate new duration for right resize
                                let dragDistanceInBeats = value.translation.width / CGFloat(state.effectivePixelsPerBeat)
                                var newDuration = resizeStartDuration + Double(dragDistanceInBeats)
                                
                                // Ensure minimum duration (0.25 beats)
                                newDuration = max(0.25, newDuration)
                                
                                // Snap to grid
                                let endBeat = clip.startBeat + newDuration
                                let snappedEndBeat = snapToNearestGridMarker(endBeat)
                                newDuration = snappedEndBeat - clip.startBeat
                                
                                // Preview the new selection size
                                state.startSelection(at: clip.startBeat, trackId: track.id)
                                state.updateSelection(to: clip.startBeat + newDuration)
                            }
                            .onEnded { value in
                                guard isResizing && !isResizingLeft else { return }
                                
                                // Calculate final duration
                                let dragDistanceInBeats = value.translation.width / CGFloat(state.effectivePixelsPerBeat)
                                var newDuration = resizeStartDuration + Double(dragDistanceInBeats)
                                
                                // Ensure minimum duration
                                newDuration = max(0.25, newDuration)
                                
                                // Snap to grid
                                let endBeat = clip.startBeat + newDuration
                                let snappedEndBeat = snapToNearestGridMarker(endBeat)
                                newDuration = snappedEndBeat - clip.startBeat
                                
                                // Apply the resize if duration actually changed
                                if abs(newDuration - clip.duration) > 0.001 {
                                    let success = midiViewModel.resizeMidiClip(
                                        trackId: track.id,
                                        clipId: clip.id,
                                        newDuration: newDuration
                                    )
                                    
                                    if success {
                                        // Update selection to match new clip size
                                        state.startSelection(at: clip.startBeat, trackId: track.id)
                                        state.updateSelection(to: clip.startBeat + newDuration)
                                    } else {
                                        // Reset selection to original clip size
                                        state.startSelection(at: clip.startBeat, trackId: track.id)
                                        state.updateSelection(to: clip.endBeat)
                                    }
                                } else {
                                    // No change, just reset selection
                                    state.startSelection(at: clip.startBeat, trackId: track.id)
                                    state.updateSelection(to: clip.endBeat)
                                }
                                
                                // End the resize interaction
                                projectViewModel.interactionManager.endClipResize()
                                isResizing = false
                                
                                // Reset cursor if still hovering
                                if isHoveringRightResizeArea {
                                    NSCursor.resizeLeftRight.set()
                                } else {
                                    NSCursor.arrow.set()
                                }
                            }
                    )
                }
            }
            .frame(width: width, height: clipHeight)
            .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
            // Add right-click gesture as a simultaneous gesture to the overall clip
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        // Check if this is a right-click (secondary click)
                        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
                            // Let the interaction manager know we're processing a right-click
                            if projectViewModel.interactionManager.startRightClick() {
                                // First select the clip
                                selectThisClip()
                                
                                // End the right-click interaction after a short delay
                                // This gives time for the context menu to appear before allowing other interactions
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    projectViewModel.interactionManager.endRightClick()
                                }
                            }
                        }
                    }
            )
            .contextMenu {
                Button("Rename Clip") {
                    newClipName = clip.name
                    showRenameDialog = true
                }
                
                Button("Copy Clip") {
                    menuCoordinator.copySelectedClip()
                }
                
                Button("Paste Clip") {
                    menuCoordinator.pasteClip()
                }
                
                Button("Delete Clip") {
                    // midiViewModel.removeMidiClip(trackId: track.id, clipId: clip.id)
                    menuCoordinator.deleteSelectedClip()
                }
                
                Divider()
                
                Button("Edit Notes") {
                    // print("Edit notes functionality will be implemented later")
                }
            }
        }
        .frame(width: width, height: clipHeight)
        .position(x: startX + width/2, y: clipHeight/2)
        .zIndex(40) // Ensure clips are above other elements for better interaction
        .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.7, blendDuration: 0.1), value: clip.startBeat) // Animate when the actual clip position changes
        .alert("Rename Clip", isPresented: $showRenameDialog) {
            TextField("Clip Name", text: $newClipName)
            
            Button("Cancel", role: .cancel) {
                showRenameDialog = false
            }
            
            Button("Rename") {
                renameClip(to: newClipName)
                showRenameDialog = false
            }
        } message: {
            Text("Enter a new name for this clip")
        }
    }
    
    // Function to select this clip
    private func selectThisClip() {
        // Select the track
        projectViewModel.selectTrack(id: track.id)
        
        // Create a selection that matches the clip's duration
        state.startSelection(at: clip.startBeat, trackId: track.id)
        state.updateSelection(to: clip.endBeat)
        
        // Move playhead to the start of the clip
        projectViewModel.seekToBeat(clip.startBeat)
        
        // Print debug info
        //        print("Clip selected: \(clip.name) from \(clip.startBeat) to \(clip.endBeat)")
    }
    
    // Rename the clip
    private func renameClip(to newName: String) {
        guard !newName.isEmpty else { return }
        
        // Use the MidiViewModel to rename the clip
        _ = midiViewModel.renameMidiClip(trackId: track.id, clipId: clip.id, newName: newName)
    }
    
    /// Snaps a raw beat position to the nearest visible grid marker based on the current zoom level
    private func snapToNearestGridMarker(_ rawBeatPosition: Double) -> Double {
        let timeSignature = projectViewModel.timeSignatureBeats
        
        // Use the new gridDivision property to determine snap behavior
        switch state.gridDivision {
        case .sixteenth: // 1/16 note
            // Snap to sixteenth notes (0.25 beat)
            return round(rawBeatPosition * 4.0) / 4.0
            
        case .eighth: // 1/8 note
            // Snap to eighth notes (0.5 beat)
            return round(rawBeatPosition * 2.0) / 2.0
            
        case .quarter: // 1/4 note
            // Snap to quarter notes (1 beat)
            return round(rawBeatPosition)
            
        case .half: // 1/2 note
            // Snap to half notes (2 beats in 4/4)
            let beatsPerBar = Double(timeSignature)
            let barIndex = floor(rawBeatPosition / beatsPerBar)
            let positionInBar = rawBeatPosition - (barIndex * beatsPerBar)
            
            // Check which marker we're closest to
            if positionInBar < beatsPerBar / 4.0 {
                // Snap to start of bar
                return barIndex * beatsPerBar
            } else if positionInBar > (beatsPerBar * 3.0) / 4.0 {
                // Snap to start of next bar
                return (barIndex + 1) * beatsPerBar
            } else {
                // Snap to half-bar
                return barIndex * beatsPerBar + beatsPerBar / 2.0
            }
            
        case .bar, .twoBar, .fourBar: // Full bar or multi-bar
            // Snap to bar boundaries
            let beatsPerBar = Double(timeSignature)
            let barIndex = floor(rawBeatPosition / beatsPerBar)
            let positionInBar = rawBeatPosition - (barIndex * beatsPerBar)
            
            // Check if we're closer to the start of the bar or the next bar
            if positionInBar < beatsPerBar / 2.0 {
                // Snap to start of bar
                return barIndex * beatsPerBar
            } else {
                // Snap to start of next bar
                return (barIndex + 1) * beatsPerBar
            }
        }
    }
}

#Preview {
    let projectVM = ProjectViewModel()
    let track = Track.samples.first(where: { $0.type == .midi })!
    let trackVM = projectVM.trackViewModelManager.viewModel(for: track)
    
    return MidiClipView(
        clip: MidiClip(name: "Test Clip", startBeat: 4, duration: 4),
        track: track,
        state: TimelineStateViewModel(),
        projectViewModel: projectVM,
        trackViewModel: trackVM
    )
    .environmentObject(ThemeManager())
    .environmentObject(MenuCoordinator())
    .frame(width: 400, height: 70)
}
