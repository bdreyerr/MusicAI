import SwiftUI
import AppKit

/// View for displaying an audio clip on a track
struct AudioClipView: View {
    let clip: AudioClip
    let track: Track
    @ObservedObject var state: TimelineStateViewModel
    @ObservedObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    // Computed property to access the Audio view model
    private var audioViewModel: AudioViewModel {
        return projectViewModel.audioViewModel
    }
    
    // State for hover and selection
    @State private var isHovering: Bool = false
    @State private var isDragging: Bool = false
    @State private var showRenameDialog: Bool = false
    @State private var newClipName: String = ""
    @State private var dragStartBeat: Double = 0 // Track the starting beat position for drag
    @State private var dragStartLocation: CGPoint = .zero // Track the starting location for drag
    
    // Store generated waveform data to avoid regenerating on each redraw
    private let placeholderWaveformData: [CGFloat]
    
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
    
    // Initialize with additional setup for waveform data
    init(clip: AudioClip, track: Track, state: TimelineStateViewModel, projectViewModel: ProjectViewModel) {
        self.clip = clip
        self.track = track
        self.state = state
        self.projectViewModel = projectViewModel
        
        // Generate placeholder waveform data only once during initialization
        if clip.waveformData.isEmpty {
            // Create a consistent number of data points based on clip duration
            let pointCount = 50 // Reduced number of points for a cleaner look
            var waveformPoints = [CGFloat]()
            
            for i in 0..<pointCount {
                // Use a smooth sine wave pattern instead of random noise
                // This creates a clean, simple waveform that looks good at any zoom level
                let normalizedPosition = Double(i) / Double(pointCount - 1) // 0.0 to 1.0
                
                // Create a smooth sine wave with some variation based on clip ID
                // to ensure different clips have different patterns
                let frequency = 2.0 + Double(abs(clip.id.hashValue % 3)) * 0.5 // Varies between 2.0 and 3.5
                let phase = Double(clip.id.hashValue % 100) / 100.0 * Double.pi // Random phase shift
                
                // Calculate amplitude using a sine function for smoothness
                let amplitude = CGFloat(sin(normalizedPosition * Double.pi * frequency + phase) * 0.7) * 8.0
                
                waveformPoints.append(amplitude)
            }
            
            self.placeholderWaveformData = waveformPoints
        } else {
            // If the clip already has waveform data, convert it to CGFloat
            self.placeholderWaveformData = clip.waveformData.map { CGFloat($0) }
        }
    }
    
    var body: some View {
        // Calculate position and size based on timeline state
        let startX = CGFloat(clip.startBeat * state.effectivePixelsPerBeat)
        let width = CGFloat(clip.duration * state.effectivePixelsPerBeat)
        
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
                
                // Clip name
                Text(clip.name)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(6)
                    .lineLimit(1)
                
                // Waveform visualization using pre-generated data
                if clip.waveformData.isEmpty {
                    // Draw waveform using the pre-generated data
                    Path { path in
                        let height = track.height - 30
                        let middle = height / 2
                        
                        // Start at the left edge, middle height
                        path.move(to: CGPoint(x: 10, y: middle))
                        
                        // Calculate the step size based on available width and data points
                        let step = (width - 20) / CGFloat(placeholderWaveformData.count - 1)
                        
                        // Draw the waveform using the pre-generated data with smooth curves
                        for (index, amplitude) in placeholderWaveformData.enumerated() {
                            let x = 10 + CGFloat(index) * step
                            let y = middle + amplitude
                            
                            // Use addLine for a cleaner look
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    .stroke(Color.white.opacity(0.8), lineWidth: 1.5)
                    .padding(.top, 24)
                }
            }
            .frame(width: width, height: track.height - 4)
            .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
            .contentShape(Rectangle()) // Ensure the entire area is clickable
            .onTapGesture {
                // print("Tap detected directly on AudioClipView")
                selectThisClip()
            }
            .onHover { hovering in
                isHovering = hovering
                if hovering {
                    // Change cursor based on whether the clip is selected
                    if isSelected {
                        NSCursor.openHand.set()
                        // print("Hovering over selected clip: \(clip.name) - showing open hand cursor")
                    } else {
                        NSCursor.pointingHand.set()
                    }
                    // print("Hovering over clip: \(clip.name) at position \(clip.startBeat)-\(clip.endBeat)")
                } else if !isDragging {
                    NSCursor.arrow.set()
                }
            }
            // Add drag gesture for moving the clip - only works when the clip is selected
            .highPriorityGesture(
                DragGesture(minimumDistance: 5) // Require a minimum drag distance to start
                    .onChanged { value in
//                        print("🔊 AUDIO DRAG DETECTED: Clip \(clip.name) (id: \(clip.id))")
                        
                        // If the clip isn't selected yet, select it first
                        if !isSelected {
//                            print("🔊 AUDIO DRAG: Clip not selected, selecting now")
                            selectThisClip()
                        }
                        
                        // Check if we can start a clip drag
                        if !isDragging && !projectViewModel.interactionManager.canStartClipDrag() {
//                            print("🔊 AUDIO DRAG: Cannot start drag - interaction manager denied request")
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
//                                print("🔊 AUDIO DRAG START: Clip \(clip.name) (id: \(clip.id)) - Starting position: \(dragStartBeat)")
                            } else {
//                                print("🔊 AUDIO DRAG: Start failed - interaction manager denied request")
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
                            
//                            print("🔊 AUDIO DRAG UPDATE: Clip \(clip.name) - Preview position: \(finalPosition)")
                            
                            // Update the selection to preview the new position
                            // This will show where the clip will end up without moving it
                            state.startSelection(at: finalPosition, trackId: track.id)
                            state.updateSelection(to: finalPosition + clip.duration)
                        }
                    }
                    .onEnded { value in
//                        print("🔊 AUDIO DRAG END DETECTED: Clip \(clip.name) (id: \(clip.id))")
                        
                        // Only process if we were actually dragging
                        guard isDragging else {
//                            print("🔊 AUDIO DRAG END: Not dragging, ignoring")
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
                        
//                        print("🔊 AUDIO DRAG CALCULATION: Clip \(clip.name) - Start beat: \(dragStartBeat) - Final position: \(finalPosition)")
                        
                        // Only move if the position actually changed
                        if abs(finalPosition - clip.startBeat) > 0.001 {
                            // Move the clip to the new position using the Audio view model
                            let success = audioViewModel.moveAudioClip(
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
                                // print("Right-click detected on AudioClipView")
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
                    audioViewModel.removeAudioClip(trackId: track.id, clipId: clip.id)
                }
                
                Divider()
                
                Button("Edit Audio") {
                    // print("Edit audio functionality will be implemented later")
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
        
        // Use the AudioViewModel to rename the clip
        _ = audioViewModel.renameAudioClip(trackId: track.id, clipId: clip.id, newName: newName)
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
    AudioClipView(
        clip: AudioClip(name: "Test Audio", startBeat: 4, duration: 4),
        track: Track.samples.first(where: { $0.type == .audio })!,
        state: TimelineStateViewModel(),
        projectViewModel: ProjectViewModel()
    )
    .environmentObject(ThemeManager())
    .frame(width: 400, height: 70)
}
