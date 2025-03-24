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
    
    // Add observation of MidiEditorViewModel's clip updates
    @State private var clipUpdateTrigger: Bool = false
    
    // Computed property to access the MIDI view model
    private var midiViewModel: MidiViewModel {
        return projectViewModel.midiViewModel
    }
    
    // Add computed property to get current clip state
    private var currentClip: MidiClip {
        // Find the most up-to-date version of the clip from the project
        if let updatedTrack = projectViewModel.tracks.first(where: { $0.id == track.id }),
           let updatedClip = updatedTrack.midiClips.first(where: { $0.id == clip.id }) {
            return updatedClip
        }
        return clip
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
    @State private var showingClipColorPicker: Bool = false // Track if color picker is visible
    @State private var currentClipColor: Color? // Track the current clip color for UI updates
    @State private var isOptionDragging: Bool = false // Track if we're option-dragging for duplication
    @State private var originalClipVisible: Bool = true // Track if the original clip should be visible during drag
    
    // Helper function to calculate high contrast color for notes
    private func getNotesColor(_ baseColor: Color) -> Color {
        // Convert the Color to NSColor to access components
        let nsColor = NSColor(baseColor)
        
        // Get color components
        guard let rgb = nsColor.usingColorSpace(.sRGB) else {
            return .white // Fallback to white if conversion fails
        }
        
        // Calculate perceived brightness using standard luminance formula
        let brightness = (rgb.redComponent * 0.299 + rgb.greenComponent * 0.587 + rgb.blueComponent * 0.114)
        
        if brightness < 0.6 {
            // For darker colors, use white with a tint of the base color
            return Color(
                NSColor(red: min(1, rgb.redComponent + 0.7),
                       green: min(1, rgb.greenComponent + 0.7),
                       blue: min(1, rgb.blueComponent + 0.7),
                       alpha: 1.0)
            )
        } else {
            // For lighter colors, use black with a tint of the base color
            return Color(
                NSColor(red: max(0, rgb.redComponent - 0.7),
                       green: max(0, rgb.greenComponent - 0.7),
                       blue: max(0, rgb.blueComponent - 0.7),
                       alpha: 1.0)
            )
        }
    }
    
    // Computed property to determine if resize handles should be visible
    private var showResizeHandles: Bool {
        return isHovering || isHoveringLeftResizeArea || isHoveringRightResizeArea || isDragging || isResizing
    }
    
    // Computed property to check if this clip is selected
    private var isSelected: Bool {
        // First check if this clip is in the multi-selection
        if state.isClipSelected(clipId: clip.id) {
            return true
        }
        
        // If not in multi-selection, check traditional selection
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
        
        // Initialize the current clip color
        self._currentClipColor = State(initialValue: clip.color)
    }
    
    var body: some View {
        // Calculate position and size based on timeline state
        let startX = CGFloat(currentClip.startBeat * state.effectivePixelsPerBeat)
        let width = CGFloat(currentClip.duration * state.effectivePixelsPerBeat)
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
                    .fill(currentClipColor ?? track.effectiveColor)
                    .opacity(isSelected ? 0.9 : (isHovering ? 0.8 : 0.6))
                    .opacity((!originalClipVisible && isDragging) ? 0 : 1) // Hide original clip during non-option drag
                
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
                
                // Notes visualization (placeholder for now)
                if !trackViewModel.isCollapsed && currentClip.notes.isEmpty {
                    //                    Text("Empty clip")
                    //                        .font(.caption2)
                    //                        .foregroundColor(.white.opacity(0.7))
                    //                        .padding(.top, 24)
                    //                        .padding(.leading, 6)
                } else if !trackViewModel.isCollapsed && !currentClip.notes.isEmpty {
                    // Draw note preview
                    Canvas { context, size in
                        // Calculate dimensions for note preview
                        let previewHeight = clipHeight - 30 // Leave space for title bar
                        let previewY = 25.0 // Start below title bar
                        
                        // Find pitch range in the clip
                        let pitches = currentClip.notes.map { $0.pitch }
                        let minPitch = pitches.min() ?? 0
                        let maxPitch = pitches.max() ?? 127
                        let pitchRange = max(maxPitch - minPitch, 12) // At least one octave range
                        
                        // Calculate vertical scaling
                        let noteHeight = previewHeight / CGFloat(pitchRange)
                        
                        // Draw each note
                        for note in currentClip.notes {
                            // Calculate horizontal position and width
                            let noteStartX = (note.startBeat / currentClip.duration) * size.width
                            let noteWidth = (note.duration / currentClip.duration) * size.width
                            
                            // Calculate vertical position (invert pitch to draw from bottom up)
                            let normalizedPitch = CGFloat(note.pitch - minPitch)
                            let noteY = previewY + (previewHeight - (normalizedPitch * noteHeight) - noteHeight)
                            
                            // Create note rectangle
                            let noteRect = Path(roundedRect: CGRect(
                                x: noteStartX,
                                y: noteY,
                                width: max(2, noteWidth), // Minimum width of 2 pixels
                                height: max(2, noteHeight - 1) // Leave 1 pixel gap between notes
                            ), cornerRadius: 1)
                            
                            // Use high contrast color for notes
                            let baseColor = currentClipColor ?? track.effectiveColor
                            let notesColor = getNotesColor(baseColor)
                            context.fill(noteRect, with: .color(notesColor.opacity(0.9)))
                        }
                    }
                }
            }
            .frame(width: width, height: clipHeight)
            .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
            .allowsHitTesting(false)
            
            
            // Title Bar
            VStack(spacing: 0) {
                // Title bar with clip name
                
                // Main Drag able content
                ZStack(alignment: .leading) {
                    
                    HStack(spacing: 0) {
                        // Left Resize
                        Rectangle()
                            .fill(Color.black.opacity(0.1))
                            .frame(width: 15,height: trackViewModel.isCollapsed ? 20 : 24)
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
                        
                        
                        Rectangle()
                            .fill(Color.black.opacity(0.1))
                            .frame(height: trackViewModel.isCollapsed ? 20 : 24)
                        
                        
                        // Right resize
                        Rectangle()
                            .fill(Color.black.opacity(0.1))
                            .frame(width: 15, height: trackViewModel.isCollapsed ? 20 : 24)
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
                    
//                    Rectangle()
//                        .fill(Color.clear)
//                        .frame(height: trackViewModel.isCollapsed ? 20 : 24)
//                        .border(Color.white.opacity(0.3), width: 1)
//                        .cornerRadius(15)
                    
                    Text(clip.name)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .lineLimit(1)
                }
                .onHover { hovering in
                    isHovering = hovering
                    isHoveringLeftResizeArea = false
                    isHoveringRightResizeArea = false
                    
                    if hovering && !isResizing && !isDragging {
                        // Check if option key is held
                        if NSEvent.modifierFlags.contains(.option) {
                            NSCursor.dragCopy.set()
                        } else if isSelected {
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
                                
                                // Check if option key is held at the start of drag
                                isOptionDragging = NSEvent.modifierFlags.contains(.option)
                                
                                // Inform the interaction manager that we're starting a clip drag
                                if projectViewModel.interactionManager.startClipDrag() {
                                    dragStartBeat = clip.startBeat
                                    dragStartLocation = value.startLocation
                                    isDragging = true
                                    
                                    // Set appropriate cursor
                                    if isOptionDragging {
                                        NSCursor.dragCopy.set()
                                        originalClipVisible = true
                                    } else {
                                        NSCursor.closedHand.set()
                                        originalClipVisible = false
                                    }
                                } else {
                                    return
                                }
                            }
                            
                            // Check if option key state has changed during drag
                            let isOptionHeld = NSEvent.modifierFlags.contains(.option)
                            if isOptionHeld != isOptionDragging {
                                isOptionDragging = isOptionHeld
                                originalClipVisible = isOptionHeld
                                
                                // Update cursor
                                if isOptionHeld {
                                    NSCursor.dragCopy.set()
                                } else {
                                    NSCursor.closedHand.set()
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
                                // Check for overlaps at the target position
                                let wouldOverlap = track.midiClips.contains { otherClip in
                                    // When option-dragging (duplicating), also check overlap with original clip
                                    if isOptionDragging {
                                        let newEndBeat = finalPosition + clip.duration
                                        return finalPosition < otherClip.endBeat && newEndBeat > otherClip.startBeat
                                    } else {
                                        // For regular dragging, ignore the clip being dragged
                                        guard otherClip.id != clip.id else { return false }
                                        let newEndBeat = finalPosition + clip.duration
                                        return finalPosition < otherClip.endBeat && newEndBeat > otherClip.startBeat
                                    }
                                }
                                
                                if !wouldOverlap {
                                    if isOptionDragging {
                                        // Create a duplicate clip at the new position
                                        let duplicateClip = MidiClip(
                                            name: clip.name,
                                            startBeat: finalPosition,
                                            duration: clip.duration,
                                            color: clip.color,
                                            notes: clip.notes
                                        )
                                        
                                        // Add the duplicate clip to the track
                                        var trackCopy = track
                                        trackCopy.addMidiClip(duplicateClip)
                                        
                                        // Update the track in the project
                                        if let trackIndex = projectViewModel.tracks.firstIndex(where: { $0.id == track.id }) {
                                            projectViewModel.updateTrack(at: trackIndex, with: trackCopy)
                                        }
                                        
                                        // Update selection to the new clip
                                        state.clearSelectedClips()
                                        state.addClipToSelection(clipId: duplicateClip.id)
                                        state.startSelection(at: finalPosition, trackId: track.id)
                                        state.updateSelection(to: finalPosition + clip.duration)
                                    } else {
                                        // Move the original clip to the new position
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
                                    }
                                } else {
                                    // Reset selection to original position if there would be an overlap
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
                            isOptionDragging = false
                            originalClipVisible = true
                            dragStartLocation = .zero
                            
                            // Reset cursor based on hover state
                            if isHovering {
                                if NSEvent.modifierFlags.contains(.option) {
                                    NSCursor.dragCopy.set()
                                } else {
                                    NSCursor.openHand.set()
                                }
                            } else {
                                NSCursor.arrow.set()
                            }
                        }
                )
                .onTapGesture {
                    selectThisClip()
                }
                
                
                Spacer()
            }
            .frame(height: clipHeight)
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
                
                Button("Copy Clip") {
                    menuCoordinator.copySelectedClip()
                }
                .keyboardShortcut("c", modifiers: .command)
                
                Button("Paste Clip") {
                    menuCoordinator.pasteClip()
                }
                .keyboardShortcut("v", modifiers: .command)
                
                Button("Duplicate Clip") {
                    menuCoordinator.duplicateSelectedClip()
                }
                .keyboardShortcut("d", modifiers: .command)
                
                Button("Delete Clip") {
                    // midiViewModel.removeMidiClip(trackId: track.id, clipId: clip.id)
                    menuCoordinator.deleteSelectedClip()
                }
                .keyboardShortcut(.delete)
                
                Button("Rename Clip") {
                    newClipName = clip.name
                    showRenameDialog = true
                }
                
                Button("Change Color") {
                    showingClipColorPicker = true
                }
            }
        }
        .frame(width: width, height: clipHeight)
        .position(x: startX + width/2, y: clipHeight/2)
        .zIndex(40) // Ensure clips are above other elements for better interaction
        .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.7, blendDuration: 0.1), value: clip.startBeat) // Animate when the actual clip position changes
        .animation(.easeInOut(duration: 0.2), value: currentClipColor) // Animate when color changes
        .popover(isPresented: $showingClipColorPicker, arrowEdge: .top) {
            VStack(spacing: 10) {
                Text("Clip Color")
                    .font(.headline)
                    .padding(.top, 8)
                
                ColorPicker("Select Color", selection: Binding(
                    get: { currentClipColor ?? track.effectiveColor },
                    set: { newColor in
                        updateClipColor(newColor)
                    }
                ))
                .padding(.horizontal)
                
                Button("Reset to Track Color") {
                    updateClipColor(nil)
                    showingClipColorPicker = false
                }
                .padding(.bottom, 8)
            }
            .frame(width: 250)
            .padding(8)
        }
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
        // Check if shift or command key is pressed for multi-selection
        let isShiftKeyPressed = NSEvent.modifierFlags.contains(.shift)
        let isCommandKeyPressed = NSEvent.modifierFlags.contains(.command)
        
        if isShiftKeyPressed || isCommandKeyPressed {
            // Toggle this clip in the multiple selection
            state.toggleClipSelection(clipId: clip.id)
            
            // If this is the first clip in the selection, also select the track
            if state.selectedClipCount == 1 {
                projectViewModel.selectTrack(id: track.id)
            }
            
            // If the clip was just added to selection, also update the timeline selection
            if state.isClipSelected(clipId: clip.id) {
                state.startSelection(at: clip.startBeat, trackId: track.id)
                state.updateSelection(to: clip.endBeat)
                
                // Move playhead to the start of the clip
                projectViewModel.seekToBeat(clip.startBeat)
            }
        } else {
            // Clear any existing multi-selection
            state.clearSelectedClips()
            
            // Add just this clip to the selection
            state.addClipToSelection(clipId: clip.id)
            
            // Select the track
            projectViewModel.selectTrack(id: track.id)
            
            // Create a selection that matches the clip's duration
            state.startSelection(at: clip.startBeat, trackId: track.id)
            state.updateSelection(to: clip.endBeat)
            
            // Move playhead to the start of the clip
            projectViewModel.seekToBeat(clip.startBeat)
        }
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
    
    // Function to update the clip color
    private func updateClipColor(_ newColor: Color?) {
        // Use the MidiViewModel to update the clip color
        let success = midiViewModel.updateMidiClipColor(trackId: track.id, clipId: clip.id, newColor: newColor)
        
        if success {
            // Update our local state to force a UI refresh
            currentClipColor = newColor
            
            // Close the color picker if needed
            if newColor == nil {
                showingClipColorPicker = false
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
