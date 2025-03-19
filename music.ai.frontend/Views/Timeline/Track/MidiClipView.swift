import SwiftUI
import AppKit

/// View for displaying a MIDI clip on a track
struct MidiClipView: View {
    let clip: MidiClip
    let track: Track
    @ObservedObject var state: TimelineStateViewModel
    @ObservedObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    // Computed property to access the MIDI view model
    private var midiViewModel: MidiViewModel {
        return projectViewModel.midiViewModel
    }
    
    // State for hover and selection
    @State private var isHovering: Bool = false
    @State private var isDragging: Bool = false
    @State private var showRenameDialog: Bool = false
    @State private var newClipName: String = ""
    @State private var dragStartBeat: Double = 0 // Track the starting beat position for drag
    @State private var dragStartLocation: CGPoint = .zero // Track the starting location for drag
    
    // State for resize operations
    @State private var isResizingLeft: Bool = false
    @State private var isResizingRight: Bool = false
    @State private var isHoveringLeftEdge: Bool = false
    @State private var isHoveringRightEdge: Bool = false
    @State private var originalStartBeat: Double = 0
    @State private var originalDuration: Double = 0
    @State private var isNearLeftEdge: Bool = false
    @State private var isNearRightEdge: Bool = false
    
    // Computed property to check if this clip is selected
    private var isSelected: Bool {
        guard state.selectionActive,
                state.selectionTrackId == track.id else {
            return false
        }
        
        // Check if the selection range matches this clip's range
        let (selStart, selEnd) = state.normalizedSelectionRange
        return abs(selStart - clip.startBeat) < 0.001 &&
        abs(selEnd - clip.endBeat) < 0.001
    }
    
    var body: some View {
        // Calculate position and size based on timeline state
        let startX = CGFloat(clip.startBeat * state.effectivePixelsPerBeat)
        let width = CGFloat(clip.duration * state.effectivePixelsPerBeat)
        
        // Define resize handle width - increase from 8 to 12 for easier grabbing
        let handleWidth: CGFloat = 12
        
        // Use a ZStack to position the clip correctly
        ZStack(alignment: .topLeading) {
            // Empty view to take up the entire track width
            Color.clear
                .frame(width: width, height: track.height - 4)
                .allowsHitTesting(false) // Don't block clicks
            
            // Clip background with content
            ZStack(alignment: .topLeading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(clip.color ?? track.effectiveColor)
                    .opacity(isSelected ? 0.9 : (isHovering ? 0.8 : 0.6))
                
                // Selection border
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.white, lineWidth: isSelected ? 2 : 0)
                    .opacity(isSelected ? 0.8 : 0)
                
                // Dragging indicator
                if isDragging {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
                        .foregroundColor(.white)
                        .opacity(0.9)
                }
                
                // Resizing indicators
                if isResizingLeft || isResizingRight {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
                        .foregroundColor(.yellow)
                        .opacity(0.9)
                }
                
                // Clip name
                Text(clip.name)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(6)
                    .lineLimit(1)
                
                // Notes visualization (placeholder for now)
                if clip.notes.isEmpty {
                    Text("Empty clip")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.top, 24)
                        .padding(.leading, 6)
                }
                
                // Left resize handle with combined visual indicator and interaction
                ZStack {
                    // Visual indicator - always visible but more prominent on hover
                    Rectangle()
                        .fill(Color.white.opacity(isHoveringLeftEdge || isResizingLeft ? 0.5 : 0.3))
                        .frame(width: handleWidth * 0.75, height: track.height - 8)
                    
                    // Invisible touch target (larger than the visual indicator)
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: handleWidth, height: track.height - 4)
                        .contentShape(Rectangle())
                }
                .position(x: handleWidth/2, y: (track.height - 4)/2)
                .onHover { hovering in
                    if !isDragging && !isResizingRight {
                        isHoveringLeftEdge = hovering
                        updateCursorForLeftEdge()
                    }
                }
                .highPriorityGesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            // If this is the start of the drag, select the clip and store initial values
                            if !isResizingLeft && !isResizingRight && !isDragging {
                                if !isSelected {
                                    selectThisClip()
                                }
                                
                                if projectViewModel.interactionManager.startClipResize() {
                                    isResizingLeft = true
                                    originalStartBeat = clip.startBeat
                                    originalDuration = clip.duration
                                    NSCursor.resizeLeftRight.set()
                                }
                            }
                            
                            if isResizingLeft {
                                // Calculate distance dragged in beats
                                let dragDistanceInBeats = value.translation.width / CGFloat(state.effectivePixelsPerBeat)
                                
                                // Calculate the new start position
                                let rawNewStartBeat = originalStartBeat + Double(dragDistanceInBeats)
                                
                                // Snap to grid
                                let snappedStartBeat = snapToNearestGridMarker(rawNewStartBeat)
                                
                                // Calculate maximum allowed start position (to maintain minimum duration)
                                let originalEndBeat = originalStartBeat + originalDuration
                                let minimumDuration = 0.25 // Minimum 1/4 beat duration
                                let maxStartBeat = originalEndBeat - minimumDuration
                                
                                // Ensure we don't go negative or make the clip too short
                                let finalStartBeat = max(0, min(snappedStartBeat, maxStartBeat))
                                
                                // Preview the resize by updating the selection
                                state.startSelection(at: finalStartBeat, trackId: track.id)
                                state.updateSelection(to: originalEndBeat)
                            }
                        }
                        .onEnded { value in
                            guard isResizingLeft else { return }
                            
                            // Calculate distance dragged in beats
                            let dragDistanceInBeats = value.translation.width / CGFloat(state.effectivePixelsPerBeat)
                            
                            // Calculate the new start position
                            let rawNewStartBeat = originalStartBeat + Double(dragDistanceInBeats)
                            
                            // Snap to grid
                            let snappedStartBeat = snapToNearestGridMarker(rawNewStartBeat)
                            
                            // Calculate maximum allowed start position (to maintain minimum duration)
                            let originalEndBeat = originalStartBeat + originalDuration
                            let minimumDuration = 0.25 // Minimum 1/4 beat duration
                            let maxStartBeat = originalEndBeat - minimumDuration
                            
                            // Ensure we don't go negative or make the clip too short
                            let finalStartBeat = max(0, min(snappedStartBeat, maxStartBeat))
                            
                            // Only resize if the position actually changed
                            if abs(finalStartBeat - originalStartBeat) > 0.001 {
                                // Resize the clip from the start
                                let success = midiViewModel.resizeMidiClipStart(
                                    trackId: track.id,
                                    clipId: clip.id,
                                    newStartBeat: finalStartBeat
                                )
                                
                                if success {
                                    // Update the selection to match the new clip bounds
                                    state.startSelection(at: finalStartBeat, trackId: track.id)
                                    state.updateSelection(to: originalEndBeat)
                                } else {
                                    // Reset the selection to the original clip position
                                    state.startSelection(at: originalStartBeat, trackId: track.id)
                                    state.updateSelection(to: originalStartBeat + originalDuration)
                                }
                            } else {
                                // If position didn't change, reset selection to current clip position
                                state.startSelection(at: originalStartBeat, trackId: track.id)
                                state.updateSelection(to: originalEndBeat)
                            }
                            
                            // Reset states
                            isNearLeftEdge = false
                            
                            // Clean up
                            projectViewModel.interactionManager.endClipResize()
                            isResizingLeft = false
                            updateCursorForLeftEdge()
                        }
                )
                .allowsHitTesting(true)
                .zIndex(50) // Higher z-index to ensure it's on top of other elements
                
                // Right resize handle with combined visual indicator and interaction
                ZStack {
                    // Visual indicator - always visible but more prominent on hover
                    Rectangle()
                        .fill(Color.white.opacity(isHoveringRightEdge || isResizingRight ? 0.5 : 0.3))
                        .frame(width: handleWidth * 0.75, height: track.height - 8)
                    
                    // Invisible touch target (larger than the visual indicator)
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: handleWidth, height: track.height - 4)
                        .contentShape(Rectangle())
                }
                .position(x: width - handleWidth/2, y: (track.height - 4)/2)
                .onHover { hovering in
                    if !isDragging && !isResizingLeft {
                        isHoveringRightEdge = hovering
                        updateCursorForRightEdge()
                    }
                }
                .highPriorityGesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            // If this is the start of the drag, select the clip and store initial values
                            if !isResizingRight && !isResizingLeft && !isDragging {
                                if !isSelected {
                                    selectThisClip()
                                }
                                
                                if projectViewModel.interactionManager.startClipResize() {
                                    isResizingRight = true
                                    originalStartBeat = clip.startBeat
                                    originalDuration = clip.duration
                                    NSCursor.resizeLeftRight.set()
                                }
                            }
                            
                            if isResizingRight {
                                // Calculate distance dragged in beats
                                let dragDistanceInBeats = value.translation.width / CGFloat(state.effectivePixelsPerBeat)
                                
                                // Calculate the new duration
                                let rawNewDuration = originalDuration + Double(dragDistanceInBeats)
                                
                                // Calculate the new end beat position
                                let rawNewEndBeat = originalStartBeat + rawNewDuration
                                
                                // Snap to grid
                                let snappedEndBeat = snapToNearestGridMarker(rawNewEndBeat)
                                
                                // Calculate the snapped duration
                                let snappedDuration = snappedEndBeat - originalStartBeat
                                
                                // Ensure minimum duration
                                let minimumDuration = 0.25 // Minimum 1/4 beat duration
                                let finalDuration = max(minimumDuration, snappedDuration)
                                
                                // Preview the resize by updating the selection
                                state.startSelection(at: originalStartBeat, trackId: track.id)
                                state.updateSelection(to: originalStartBeat + finalDuration)
                            }
                        }
                        .onEnded { value in
                            guard isResizingRight else { return }
                            
                            // Calculate distance dragged in beats
                            let dragDistanceInBeats = value.translation.width / CGFloat(state.effectivePixelsPerBeat)
                            
                            // Calculate the new duration
                            let rawNewDuration = originalDuration + Double(dragDistanceInBeats)
                            
                            // Calculate the new end beat position
                            let rawNewEndBeat = originalStartBeat + rawNewDuration
                            
                            // Snap to grid
                            let snappedEndBeat = snapToNearestGridMarker(rawNewEndBeat)
                            
                            // Calculate the snapped duration
                            let snappedDuration = snappedEndBeat - originalStartBeat
                            
                            // Ensure minimum duration
                            let minimumDuration = 0.25 // Minimum 1/4 beat duration
                            let finalDuration = max(minimumDuration, snappedDuration)
                            
                            // Only resize if the duration actually changed
                            if abs(finalDuration - originalDuration) > 0.001 {
                                // Resize the clip from the end
                                let success = midiViewModel.resizeMidiClipEnd(
                                    trackId: track.id,
                                    clipId: clip.id,
                                    newDuration: finalDuration
                                )
                                
                                if success {
                                    // Update the selection to match the new clip bounds
                                    state.startSelection(at: originalStartBeat, trackId: track.id)
                                    state.updateSelection(to: originalStartBeat + finalDuration)
                                } else {
                                    // Reset the selection to the original clip position
                                    state.startSelection(at: originalStartBeat, trackId: track.id)
                                    state.updateSelection(to: originalStartBeat + originalDuration)
                                }
                            } else {
                                // If duration didn't change, reset selection to current clip position
                                state.startSelection(at: originalStartBeat, trackId: track.id)
                                state.updateSelection(to: originalStartBeat + originalDuration)
                            }
                            
                            // Reset states
                            isNearRightEdge = false
                            
                            // Clean up
                            projectViewModel.interactionManager.endClipResize()
                            isResizingRight = false
                            updateCursorForRightEdge()
                        }
                )
                .allowsHitTesting(true)
                .zIndex(50) // Higher z-index to ensure it's on top of other elements
            }
            .frame(width: width, height: track.height - 4)
            .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
            .contentShape(Rectangle()) // Ensure the entire area is clickable
            .onTapGesture {
                // print("Tap detected directly on MidiClipView")
                selectThisClip()
            }
            .onHover { hovering in
                isHovering = hovering
                if hovering && !isHoveringLeftEdge && !isHoveringRightEdge {
                    // Change cursor based on whether the clip is selected
                    if isSelected {
                        NSCursor.openHand.set()
                        // print("Hovering over selected clip: \(clip.name) - showing open hand cursor")
                    } else {
                        NSCursor.pointingHand.set()
                    }
                    // print("Hovering over clip: \(clip.name) at position \(clip.startBeat)-\(clip.endBeat)")
                } else if !isDragging && !isResizingLeft && !isResizingRight && !isHoveringLeftEdge && !isHoveringRightEdge {
                    NSCursor.arrow.set()
                }
            }
            // Add drag gesture for moving the clip - only works when the clip is selected
            .highPriorityGesture(
                DragGesture(minimumDistance: 5) // Require a minimum drag distance to start
                    .onChanged { value in
                        // Calculate relative position within the clip to determine if we're near an edge
                        let relativeX = value.startLocation.x
                        isNearLeftEdge = relativeX <= handleWidth
                        isNearRightEdge = relativeX >= width - handleWidth
                        
                        // If we're near an edge, don't start a drag operation
                        if isNearLeftEdge || isNearRightEdge {
                            return
                        }
                        
                        // print("🎹 MIDI DRAG DETECTED: Clip \(clip.name) (id: \(clip.id))")
                        
                        // If the clip isn't selected yet, select it first
                        if !isSelected {
                            // print("🎹 MIDI DRAG: Clip not selected, selecting now")
                            selectThisClip()
                        }
                        
                        // Check if we can start a clip drag
                        if !isDragging && !projectViewModel.interactionManager.canStartClipDrag() {
                            // print("🎹 MIDI DRAG: Cannot start drag - interaction manager denied request")
                            return
                        }
                        
                        // If this is the start of the drag, store the starting position
                        if !isDragging {
                            // Inform the interaction manager that we're starting a clip drag
                            if projectViewModel.interactionManager.startClipDrag() {
                                dragStartBeat = clip.startBeat
                                dragStartLocation = value.startLocation
                                isDragging = true
                                NSCursor.closedHand.set()
                                // print("🎹 MIDI DRAG START: Clip \(clip.name) (id: \(clip.id)) - Starting position: \(dragStartBeat)")
                            } else {
                                // print("🎹 MIDI DRAG: Start failed - interaction manager denied request")
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
                            
                            // print("🎹 MIDI DRAG UPDATE: Clip \(clip.name) - Preview position: \(finalPosition)")
                            
                            // Update the selection to preview the new position
                            // This will show where the clip will end up without moving it
                            state.startSelection(at: finalPosition, trackId: track.id)
                            state.updateSelection(to: finalPosition + clip.duration)
                        }
                    }
                    .onEnded { value in
                        // print("🎹 MIDI DRAG END DETECTED: Clip \(clip.name) (id: \(clip.id))")
                        
                        // Only process if we were actually dragging
                        guard isDragging else {
                            // print("🎹 MIDI DRAG END: Not dragging, ignoring")
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
                        
                        // print("🎹 MIDI DRAG CALCULATION: Clip \(clip.name) - Start beat: \(dragStartBeat) - Final position: \(finalPosition)")
                        
                        // Only move if the position actually changed
                        if abs(finalPosition - clip.startBeat) > 0.001 {
                            // print("🔄 MOVING MIDI CLIP: Clip \(clip.name) from \(clip.startBeat) to \(finalPosition)")
                            
                            // Move the clip to the new position using the MIDI view model
                            // print("📞 CALLING MIDI VIEW MODEL: moveMidiClip(trackId: \(track.id), clipId: \(clip.id), newStartBeat: \(finalPosition))")
                            let success = midiViewModel.moveMidiClip(
                                trackId: track.id,
                                clipId: clip.id,
                                newStartBeat: finalPosition
                            )
                            
                            if success {
                                // print("✅ MIDI MOVE SUCCESS: Clip \(clip.name) moved to \(finalPosition)")
                                
                                // Update the selection to match the new clip position
                                state.startSelection(at: finalPosition, trackId: track.id)
                                state.updateSelection(to: finalPosition + clip.duration)
                            } else {
                                // print("❌ MIDI MOVE FAILED: Could not move clip \(clip.name) to \(finalPosition)")
                                
                                // Reset the selection to the original clip position
                                state.startSelection(at: clip.startBeat, trackId: track.id)
                                state.updateSelection(to: clip.endBeat)
                            }
                        } else {
                            // print("ℹ️ MIDI NO MOVE NEEDED: Clip \(clip.name) position unchanged")
                            
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
                            // If still hovering over the clip after drag, show open hand if selected
                            if isSelected {
                                NSCursor.openHand.set()
                            } else {
                                NSCursor.pointingHand.set()
                            }
                        } else {
                            NSCursor.arrow.set()
                        }
                    }
                , isEnabled: true)
            // Add right-click gesture as a simultaneous gesture
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        // Check if this is a right-click (secondary click)
                        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
                            // Let the interaction manager know we're processing a right-click
                            if projectViewModel.interactionManager.startRightClick() {
                                // First select the clip
                                // print("Right-click detected on MidiClipView")
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
                
                Button("Delete Clip") {
                    midiViewModel.removeMidiClip(trackId: track.id, clipId: clip.id)
                }
                
                Divider()
                
                Button("Edit Notes") {
                    // print("Edit notes functionality will be implemented later")
                }
            }
        }
        .position(x: startX + width/2, y: (track.height - 4)/2)
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
    
    // Function to update cursor when hovering over left edge
    private func updateCursorForLeftEdge() {
        if isHoveringLeftEdge {
            NSCursor.resizeLeftRight.set()
        } else if isHovering {
            if isSelected {
                NSCursor.openHand.set()
            } else {
                NSCursor.pointingHand.set()
            }
        } else {
            NSCursor.arrow.set()
        }
    }
    
    // Function to update cursor when hovering over right edge
    private func updateCursorForRightEdge() {
        if isHoveringRightEdge {
            NSCursor.resizeLeftRight.set()
        } else if isHovering {
            if isSelected {
                NSCursor.openHand.set()
            } else {
                NSCursor.pointingHand.set()
            }
        } else {
            NSCursor.arrow.set()
        }
    }
}

#Preview {
    MidiClipView(
        clip: MidiClip(name: "Test Clip", startBeat: 4, duration: 4),
        track: Track.samples.first(where: { $0.type == .midi })!,
        state: TimelineStateViewModel(),
        projectViewModel: ProjectViewModel()
    )
    .environmentObject(ThemeManager())
    .frame(width: 400, height: 70)
}
