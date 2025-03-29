import SwiftUI
import AppKit

/// View for displaying an audio clip on a track
struct AudioClipView: View {
    let clip: AudioClip
    let track: Track
    @ObservedObject var state: TimelineStateViewModel
    @ObservedObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var menuCoordinator: MenuCoordinator
    @ObservedObject var trackViewModel: TrackViewModel
    
    // Computed property to access the Audio view model
    private var audioViewModel: AudioViewModel {
        return projectViewModel.audioViewModel
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
    @State private var waveformData: [CGFloat] = [] // Waveform data for this clip
    @State private var isLoadingWaveform: Bool = false // Track loading state for waveform
    
    // Computed property to determine if resize handles should be visible
    private var showResizeHandles: Bool {
        return isHovering || isHoveringLeftResizeArea || isHoveringRightResizeArea || isDragging || isResizing
    }
    
    // Store waveform color for contrast against the clip background
    private let waveformColor: Color
    
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
        return abs(selStart - clip.startPositionInBeats) < 0.001 &&
        abs(selEnd - clip.endBeat) < 0.001
    }
    
    // Initialize with additional setup for waveform data
    init(clip: AudioClip, track: Track, state: TimelineStateViewModel, projectViewModel: ProjectViewModel, trackViewModel: TrackViewModel) {
        self.clip = clip
        self.track = track
        self.state = state
        self.projectViewModel = projectViewModel
        self.trackViewModel = trackViewModel
        
        // Initialize the current clip color
        self._currentClipColor = State(initialValue: clip.color)
        
        // Calculate contrasting color for waveform bars
        let baseColor = clip.color ?? track.effectiveColor
        let isDark = baseColor.brightness < 0.2 // Only consider very dark colors
        // Choose black by default, white only for very dark backgrounds
        self.waveformColor = isDark ? .white : .black
    }
    
    var body: some View {
        // Calculate position and size based on timeline state
        let startX = CGFloat(clip.startPositionInBeats * state.effectivePixelsPerBeat)
        let width = CGFloat(clip.durationInBeats * state.effectivePixelsPerBeat)
        let clipHeight = trackViewModel.isCollapsed ? 26 : track.height - 4 // Use fixed 26px for collapsed state
        
        // Use a ZStack to position the clip correctly
        ClipContainerView(
            clip: clip,
            track: track,
            startX: startX,
            width: width,
            clipHeight: clipHeight,
            state: state,
            projectViewModel: projectViewModel,
            trackViewModel: trackViewModel,
            isHovering: $isHovering,
            isDragging: $isDragging,
            isResizing: $isResizing,
            isHoveringLeftResizeArea: $isHoveringLeftResizeArea, 
            isHoveringRightResizeArea: $isHoveringRightResizeArea,
            showRenameDialog: $showRenameDialog,
            newClipName: $newClipName,
            dragStartBeat: $dragStartBeat,
            dragStartLocation: $dragStartLocation,
            resizeStartDuration: $resizeStartDuration,
            resizeStartPosition: $resizeStartPosition,
            isResizingLeft: $isResizingLeft,
            showingClipColorPicker: $showingClipColorPicker,
            currentClipColor: $currentClipColor,
            isOptionDragging: $isOptionDragging,
            originalClipVisible: $originalClipVisible,
            waveformData: $waveformData,
            isLoadingWaveform: $isLoadingWaveform,
            waveformColor: waveformColor,
            isSelected: isSelected,
            selectThisClip: selectThisClip,
            snapToNearestGridMarker: snapToNearestGridMarker,
            renameClip: renameClip,
            updateClipColor: updateClipColor
        )
        // Force redraw when project model changes (e.g. waveforms are loaded)
        .onReceive(projectViewModel.objectWillChange) { _ in
            // This forces the view to redraw when the AudioItem's waveforms change
            // We don't need to update any state, just receiving the change is enough
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
                state.startSelection(at: clip.startPositionInBeats, trackId: track.id)
                state.updateSelection(to: clip.endBeat)
                
                // Move playhead to the start of the clip
                projectViewModel.seekToBeat(clip.startPositionInBeats)
            }
        } else {
            // Clear any existing multi-selection
            state.clearSelectedClips()
            
            // Add just this clip to the selection
            state.addClipToSelection(clipId: clip.id)
            
            // Select the track
            projectViewModel.selectTrack(id: track.id)
            
            // Create a selection that matches the clip's duration
            state.startSelection(at: clip.startPositionInBeats, trackId: track.id)
            state.updateSelection(to: clip.endBeat)
            
            // Move playhead to the start of the clip
            projectViewModel.seekToBeat(clip.startPositionInBeats)
        }
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
    
    // Helper method to update cursor based on hover state
    private func updateCursor() {
        if isResizing {
            NSCursor.resizeLeftRight.set()
        } else if isHoveringLeftResizeArea || isHoveringRightResizeArea {
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
    
    // Helper method to update clip color
    private func updateClipColor(_ newColor: Color?) {
        // Use the AudioViewModel to update the clip color
        let success = audioViewModel.updateAudioClipColor(trackId: track.id, clipId: clip.id, newColor: newColor)
        
        if success {
            // Update our local state to force a UI refresh
            currentClipColor = newColor
            
            // Close the color picker if needed
            if newColor == nil {
                showingClipColorPicker = false
            }
        }
    }
    
    // Helper method to determine waveform color for professional appearance
    private func determineWaveformColor() -> Color {
        // Get the base color (clip color or track color)
        let baseColor = currentClipColor ?? track.effectiveColor
        
        // Calculate the perceived brightness of the background
        let brightness = baseColor.brightness
        
        if brightness < 0.3 {
            // For very dark backgrounds, use a bright, high-contrast color
            // White with slight opacity looks professional on dark backgrounds
            return Color.white.opacity(0.9)
        } else if brightness < 0.6 {
            // For medium-dark backgrounds, use a slightly softer white
            return Color.white.opacity(0.8)
        } else {
            // For lighter backgrounds, use a darker color with good contrast
            // A dark shade that's not pure black maintains professional look
            return Color(white: 0.15).opacity(0.85)
        }
    }
}

// A struct to seed the random generator for consistent results
private struct SeededRandomGenerator {
    private var seed: Int
    
    init(seed: Int) {
        // Make sure we start with a positive seed
        self.seed = abs(seed) == 0 ? 42 : abs(seed)
    }
    
    mutating func randomCGFloat(min: CGFloat, max: CGFloat) -> CGFloat {
        // Use a simple but robust xorshift algorithm
        // This avoids overflow issues with large multiplications
        var x = UInt32(truncatingIfNeeded: seed)
        x ^= x << 13
        x ^= x >> 17
        x ^= x << 5
        seed = Int(x)
        
        // Convert to normalized float in [0,1] range
        let normalizedValue = CGFloat(seed & 0x7FFFFFFF) / CGFloat(0x7FFFFFFF)
        
        // Scale to requested range
        return min + normalizedValue * (max - min)
    }
}

// Color extension to help determine if a color is dark or light
extension Color {
    var brightness: CGFloat {
        let nsColor = NSColor(self)
        
        // Convert to RGB colorspace if needed
        let rgbColor = nsColor.usingColorSpace(.sRGB) ?? nsColor
        
        // Use the components array which is safer
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        
        rgbColor.getRed(&r, green: &g, blue: &b, alpha: nil)
        
        // Simple luminance calculation (perceived brightness)
        return (r * 0.299 + g * 0.587 + b * 0.114)
    }
}

// Helper struct to break up complex view
struct ClipContainerView: View {
    let clip: AudioClip
    let track: Track
    let startX: CGFloat
    let width: CGFloat
    let clipHeight: CGFloat
    @ObservedObject var state: TimelineStateViewModel
    @ObservedObject var projectViewModel: ProjectViewModel
    @ObservedObject var trackViewModel: TrackViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var menuCoordinator: MenuCoordinator
    
    // Binding state properties from parent
    @Binding var isHovering: Bool
    @Binding var isDragging: Bool
    @Binding var isResizing: Bool
    @Binding var isHoveringLeftResizeArea: Bool
    @Binding var isHoveringRightResizeArea: Bool
    @Binding var showRenameDialog: Bool
    @Binding var newClipName: String
    @Binding var dragStartBeat: Double
    @Binding var dragStartLocation: CGPoint
    @Binding var resizeStartDuration: Double
    @Binding var resizeStartPosition: Double
    @Binding var isResizingLeft: Bool
    @Binding var showingClipColorPicker: Bool
    @Binding var currentClipColor: Color?
    @Binding var isOptionDragging: Bool
    @Binding var originalClipVisible: Bool
    @Binding var waveformData: [CGFloat]
    @Binding var isLoadingWaveform: Bool
    
    // Regular properties
    let waveformColor: Color
    let isSelected: Bool
    
    // Callback functions
    let selectThisClip: () -> Void
    let snapToNearestGridMarker: (Double) -> Double
    let renameClip: (String) -> Void
    let updateClipColor: (Color?) -> Void
    
    // Computed property to access the Audio view model
    private var audioViewModel: AudioViewModel {
        return projectViewModel.audioViewModel
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Empty view to take up the entire track width
            Color.clear
                .frame(width: width, height: clipHeight)
                .allowsHitTesting(false) // Don't block clicks
            
            // Clip background with content
            clipBackgroundView
            
            // Title Bar with drag and resize functionality
            clipTitleBarView
        }
        .frame(width: width, height: clipHeight)
        .position(x: startX + width/2, y: clipHeight/2)
        .zIndex(40) // Ensure clips are above other elements for better interaction
        .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.7, blendDuration: 0.1), value: clip.startPositionInBeats) // Animate when the actual clip position changes
        .animation(.easeInOut(duration: 0.2), value: currentClipColor) // Animate when color changes
        .simultaneousGesture(tapGesture) // Add tap gesture for click selection
        .popover(isPresented: $showingClipColorPicker, arrowEdge: .top) {
            colorPickerView
        }
        .alert("Rename Clip", isPresented: $showRenameDialog) {
            renameAlertView
        } message: {
            Text("Enter a new name for this clip")
        }
        // Force redraw when project model changes (e.g. waveforms are loaded)
        .onReceive(projectViewModel.objectWillChange) { _ in
            // This forces the view to redraw when the AudioItem's waveforms change
            // We don't need to update any state, just receiving the change is enough
        }
    }
    
    // MARK: - View Components
    
    private var clipBackgroundView: some View {
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
            
            // Display the waveform in the bottom section of the clip
            VStack {
                // Push waveform to bottom section
                Spacer().frame(height: trackViewModel.isCollapsed ? 20 : 24)
                
                // Add waveform if clip has one and track is not collapsed
                if !trackViewModel.isCollapsed {
                    if clip.audioItem.isStereo && clip.audioItem.leftWaveform != nil && clip.audioItem.rightWaveform != nil {
                        // Show stereo waveforms with left and right channels
                        VStack(spacing: 2) {
                            // Left channel
                            if let leftWaveform = clip.audioItem.leftWaveform {
                                ClipSectionWaveformView(
                                    samples: leftWaveform.samples ?? [],
                                    totalSamples: Int(clip.audioItem.lengthInSamples),
                                    clipStartSample: Int(clip.startOffsetInSamples),
                                    clipLengthSamples: Int(clip.lengthInSamples),
                                    width: width,
                                    height: (track.height - 30) / 2, // Half height for each channel
                                    stripeWidth: leftWaveform.stripeWidth,
                                    stripeSpacing: leftWaveform.stripeSpacing,
                                    color: waveformColor,
                                    channelLabel: "L"
                                )
                            }
                            
                            // Right channel
                            if let rightWaveform = clip.audioItem.rightWaveform {
                                ClipSectionWaveformView(
                                    samples: rightWaveform.samples ?? [],
                                    totalSamples: Int(clip.audioItem.lengthInSamples),
                                    clipStartSample: Int(clip.startOffsetInSamples),
                                    clipLengthSamples: Int(clip.lengthInSamples),
                                    width: width,
                                    height: (track.height - 30) / 2, // Half height for each channel
                                    stripeWidth: rightWaveform.stripeWidth,
                                    stripeSpacing: rightWaveform.stripeSpacing,
                                    color: waveformColor,
                                    channelLabel: "R"
                                )
                            } else {
                                // Show loading indicator while waveform is being generated
                                VStack {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .padding(.bottom, 2)
                                    
                                    Text("Loading...")
                                        .font(.system(size: 9))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                .frame(height: track.height - 28)
                                .padding(.horizontal, 10)
                            }
                        }
                    } else if let monoWaveform = clip.audioItem.monoWaveform {
                        // Show mono waveform (legacy or mono files)
                        ClipSectionWaveformView(
                            samples: monoWaveform.samples ?? [],
                            totalSamples: Int(clip.audioItem.lengthInSamples),
                            clipStartSample: Int(clip.startOffsetInSamples),
                            clipLengthSamples: Int(clip.lengthInSamples),
                            width: width,
                            height: track.height - 28,
                            stripeWidth: monoWaveform.stripeWidth,
                            stripeSpacing: monoWaveform.stripeSpacing,
                            color: waveformColor
                        )
                    } else {
                        // Show loading indicator while waveform is being generated
                        VStack {
                            ProgressView()
                                .scaleEffect(0.7)
                                .padding(.bottom, 2)
                            
                            Text("Loading...")
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .frame(height: track.height - 28)
                        .padding(.horizontal, 10)
                    }
                }
            }
            .padding(.bottom, 4)
        }
        .frame(width: width, height: clipHeight)
        .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
        .allowsHitTesting(false)
    }
    
    private var clipTitleBarView: some View {
        VStack(spacing: 0) {
            // Title bar with clip name
            ZStack(alignment: .leading) {
                HStack(spacing: 0) {
                    // Left Resize
                    leftResizeHandle
                    
                    // Center drag area
                    Rectangle()
                        .fill(Color.black.opacity(0.1))
                        .frame(height: trackViewModel.isCollapsed ? 20 : 24)
                        .clipped()
                    
                    // Right resize
                    rightResizeHandle
                }
                
                // Only show text if there's enough width
                if width >= 30 {
                    Text(clip.name)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .lineLimit(1)
                        .clipped() // Ensure text is clipped inside its container
                }
            }
            .simultaneousGesture(tapGesture)
            .onHover(perform: handleTitleBarHover)
            .gesture(dragGesture)
            
            Spacer()
        }
        .frame(height: clipHeight)
        .clipped() // Ensure nothing extends outside clip boundaries
        // Add right-click gesture as a simultaneous gesture to the overall clip
        .simultaneousGesture(rightClickGesture)
        .contextMenu {
            clipContextMenu
        }
    }
    
    private var leftResizeHandle: some View {
        Rectangle()
            .fill(Color.black.opacity(0.1))
            .frame(width: width < 60 ? min(8, width/4) : min(15, width/2), height: trackViewModel.isCollapsed ? 20 : 24)
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
            .gesture(leftResizeGesture)
    }
    
    private var rightResizeHandle: some View {
        Rectangle()
            .fill(Color.black.opacity(0.1))
            .frame(width: width < 60 ? min(8, width/4) : min(15, width/2), height: trackViewModel.isCollapsed ? 20 : 24)
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
            .gesture(rightResizeGesture)
    }
    
    private var colorPickerView: some View {
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
    
    private var renameAlertView: some View {
        Group {
            TextField("Clip Name", text: $newClipName)
            
            Button("Cancel", role: .cancel) {
                showRenameDialog = false
            }
            
            Button("Rename") {
                renameClip(newClipName)
                showRenameDialog = false
            }
        }
    }
    
    private var clipContextMenu: some View {
        Group {
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
                menuCoordinator.deleteSelectedClip()
            }
            .keyboardShortcut(.delete)

            Divider()

            Button("Rename Clip") {
                newClipName = clip.name
                showRenameDialog = true
            }
            
            Button("Change Color") {
                showingClipColorPicker = true
            }
        }
    }
    
    // MARK: - Gestures
    
    private var tapGesture: some Gesture {
        TapGesture()
            .onEnded {
                // Try to start a clip selection interaction
                if projectViewModel.interactionManager.startClipSelection() {
                    // Select the clip on tap
                    selectThisClip()
                    
                    // End the selection interaction immediately
                    projectViewModel.interactionManager.endClipSelection()
                }
            }
    }
    
    private var leftResizeGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                handleLeftResizeChange(value)
            }
            .onEnded { value in
                handleLeftResizeEnd(value)
            }
    }
    
    private var rightResizeGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                handleRightResizeChange(value)
            }
            .onEnded { value in
                handleRightResizeEnd(value)
            }
    }
    
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                handleDragChange(value)
            }
            .onEnded { value in
                handleDragEnd(value)
            }
    }
    
    private var rightClickGesture: some Gesture {
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
    }
    
    // MARK: - Event Handlers
    
    private func handleTitleBarHover(_ hovering: Bool) {
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
    
    private func handleLeftResizeChange(_ value: DragGesture.Value) {
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
                resizeStartDuration = clip.durationInBeats
                resizeStartPosition = clip.startPositionInBeats
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
        
        // Calculate the maximum allowed extension based on audioStartTime
        let beatDuration = clip.audioWindowDuration / clip.durationInBeats
        let maxAdditionalBeats = clip.audioStartTime / beatDuration
        let minAllowedStartBeat = resizeStartPosition - maxAdditionalBeats
        
        // Limit the start beat to not exceed the audio file bounds
        newStartBeat = max(newStartBeat, minAllowedStartBeat)
        
        // Snap to grid
        let snappedStartBeat = snapToNearestGridMarker(newStartBeat)
        
        // Calculate new duration based on the snapped start position
        let newDuration = (resizeStartPosition + resizeStartDuration) - snappedStartBeat
        
        // Preview the new selection size
        state.startSelection(at: snappedStartBeat, trackId: track.id)
        state.updateSelection(to: snappedStartBeat + newDuration)
    }
    
    private func handleLeftResizeEnd(_ value: DragGesture.Value) {
        guard isResizing && isResizingLeft else { return }
        
        // Calculate new position and duration
        let dragDistanceInBeats = value.translation.width / CGFloat(state.effectivePixelsPerBeat)
        var newStartBeat = resizeStartPosition + Double(dragDistanceInBeats)
        
        // Calculate the original end beat position
        let originalEndBeat = clip.startPositionInBeats + clip.durationInBeats
        
        // Ensure we don't go past the end of the clip
        let clipEnd = resizeStartPosition + resizeStartDuration
        newStartBeat = min(newStartBeat, clipEnd - 0.25) // Ensure minimum duration
        
        // Ensure we don't go negative
        newStartBeat = max(0, newStartBeat)
        
        // Calculate the maximum allowed extension based on audioStartTime
        let beatDuration = clip.audioWindowDuration / clip.durationInBeats
        let maxAdditionalBeats = clip.audioStartTime / beatDuration
        let minAllowedStartBeat = resizeStartPosition - maxAdditionalBeats
        
        // Limit the start beat to not exceed the audio file bounds
        newStartBeat = max(newStartBeat, minAllowedStartBeat)
        
        // Snap to grid
        let snappedStartBeat = snapToNearestGridMarker(newStartBeat)
        
        // Calculate new duration
        let newDuration = (resizeStartPosition + resizeStartDuration) - snappedStartBeat
        
        // Only apply if the position or duration actually changed
        if abs(newStartBeat - clip.startPositionInBeats) > 0.001 || abs(newDuration - clip.durationInBeats) > 0.001 {
            // Resize the clip with the new duration and position
            let (success, actualDuration) = audioViewModel.resizeAudioClip(
                trackId: track.id,
                clipId: clip.id,
                newDuration: newDuration,
                isResizingLeft: true
            )
            
            if success {
                // Calculate actual start beat based on the actual duration
                let actualStartBeat = originalEndBeat - actualDuration
                
                // Update selection to match actual clip size
                state.startSelection(at: actualStartBeat, trackId: track.id)
                state.updateSelection(to: actualStartBeat + actualDuration)
            } else {
                // Reset selection to original clip size
                state.startSelection(at: clip.startPositionInBeats, trackId: track.id)
                state.updateSelection(to: clip.endBeat)
            }
        } else {
            // No change, just reset selection
            state.startSelection(at: clip.startPositionInBeats, trackId: track.id)
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
    
    private func handleRightResizeChange(_ value: DragGesture.Value) {
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
                resizeStartDuration = clip.durationInBeats
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
        
        // Calculate beat duration (seconds per beat)
        let beatDuration = clip.audioWindowDuration / clip.durationInBeats
        
        // Calculate the maximum allowed duration based on remaining audio time
        let remainingAudioTime = clip.audioItem.durationInSeconds - clip.audioStartTime
        let maxNewDuration = remainingAudioTime / beatDuration
        
        // Limit the duration to not exceed the audio file bounds
        newDuration = min(newDuration, maxNewDuration)
        
        // Snap to grid
        let endBeat = clip.startPositionInBeats + newDuration
        let snappedEndBeat = snapToNearestGridMarker(endBeat)
        newDuration = snappedEndBeat - clip.startPositionInBeats
        
        // Reapply audio bounds limit after snapping
        newDuration = min(newDuration, maxNewDuration)
        
        // Preview the new selection size
        state.startSelection(at: clip.startPositionInBeats, trackId: track.id)
        state.updateSelection(to: clip.startPositionInBeats + newDuration)
    }
    
    private func handleRightResizeEnd(_ value: DragGesture.Value) {
        guard isResizing && !isResizingLeft else { return }
        
        // Calculate new duration
        let dragDistanceInBeats = value.translation.width / CGFloat(state.effectivePixelsPerBeat)
        var newDuration = resizeStartDuration + Double(dragDistanceInBeats)
        
        // Ensure minimum duration
        newDuration = max(0.25, newDuration)
        
        // Check if we need to limit based on original audio file duration
        if let originalDuration = clip.originalDuration {
            // Limit to the original audio file duration
            newDuration = min(newDuration, originalDuration)
        }
        
        // Snap to grid
        let endBeat = clip.startPositionInBeats + newDuration
        let snappedEndBeat = snapToNearestGridMarker(endBeat)
        newDuration = snappedEndBeat - clip.startPositionInBeats
        
        // Reapply original duration limit after snapping if needed
        if let originalDuration = clip.originalDuration {
            newDuration = min(newDuration, originalDuration)
        }
        
        // Only apply if the duration actually changed
        if abs(newDuration - clip.durationInBeats) > 0.001 {
            // Resize the clip
            let (success, actualDuration) = audioViewModel.resizeAudioClip(
                trackId: track.id,
                clipId: clip.id,
                newDuration: newDuration,
                isResizingLeft: false
            )
            
            if success {
                // Update selection to match actual clip size
                state.startSelection(at: clip.startPositionInBeats, trackId: track.id)
                state.updateSelection(to: clip.startPositionInBeats + actualDuration)
            } else {
                // Reset selection to original clip size
                state.startSelection(at: clip.startPositionInBeats, trackId: track.id)
                state.updateSelection(to: clip.endBeat)
            }
        } else {
            // No change, just reset selection
            state.startSelection(at: clip.startPositionInBeats, trackId: track.id)
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
    
    private func handleDragChange(_ value: DragGesture.Value) {
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
                dragStartBeat = clip.startPositionInBeats
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
            state.updateSelection(to: finalPosition + clip.durationInBeats)
        }
    }
    
    private func handleDragEnd(_ value: DragGesture.Value) {
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
        if abs(finalPosition - clip.startPositionInBeats) > 0.001 {
            // Check for overlaps at the target position
            let wouldOverlap = track.audioClips.contains { otherClip in
                // When option-dragging (duplicating), also check overlap with original clip
                if isOptionDragging {
                    let newEndBeat = finalPosition + clip.durationInBeats
                    return finalPosition < otherClip.endBeat && newEndBeat > otherClip.startPositionInBeats
                } else {
                    // For regular dragging, ignore the clip being dragged
                    guard otherClip.id != clip.id else { return false }
                    let newEndBeat = finalPosition + clip.durationInBeats
                    return finalPosition < otherClip.endBeat && newEndBeat > otherClip.startPositionInBeats
                }
            }
            
            if !wouldOverlap {
                if isOptionDragging {
                    // Create a duplicate clip at the new position
                    let duplicateClip = AudioClip(
                        audioItem: clip.audioItem,
                        name: clip.name,
                        startPositionInBeats: finalPosition,
                        durationInBeats: clip.durationInBeats,
                        audioFileURL: clip.audioFileURL,
                        color: clip.color,
                        originalDuration: clip.originalDuration,
                        startOffsetInSamples: clip.startOffsetInSamples,
                        lengthInSamples: clip.lengthInSamples
                    )
                    
                    // Add the duplicate clip to the track
                    var trackCopy = track
                    trackCopy.addAudioClip(duplicateClip)
                    
                    // Update the track in the project
                    if let trackIndex = projectViewModel.tracks.firstIndex(where: { $0.id == track.id }) {
                        projectViewModel.updateTrack(at: trackIndex, with: trackCopy)
                    }
                    
                    // Update selection to the new clip
                    state.clearSelectedClips()
                    state.addClipToSelection(clipId: duplicateClip.id)
                    state.startSelection(at: finalPosition, trackId: track.id)
                    state.updateSelection(to: finalPosition + clip.durationInBeats)
                } else {
                    // Move the original clip to the new position
                    let success = audioViewModel.moveAudioClip(
                        trackId: track.id,
                        clipId: clip.id,
                        newStartBeat: finalPosition
                    )
                    
                    if success {
                        // Update the selection to match the new clip position
                        state.startSelection(at: finalPosition, trackId: track.id)
                        state.updateSelection(to: finalPosition + clip.durationInBeats)
                    } else {
                        // Reset the selection to the original clip position
                        state.startSelection(at: clip.startPositionInBeats, trackId: track.id)
                        state.updateSelection(to: clip.endBeat)
                    }
                }
            } else {
                // Reset selection to original position if there would be an overlap
                state.startSelection(at: clip.startPositionInBeats, trackId: track.id)
                state.updateSelection(to: clip.endBeat)
            }
        } else {
            // If position didn't change, reset selection to current clip position
            state.startSelection(at: clip.startPositionInBeats, trackId: track.id)
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
}

/// A specialized view for rendering just the clip section of a waveform
struct ClipSectionWaveformView: View {
    let samples: [Float]
    let totalSamples: Int
    let clipStartSample: Int
    let clipLengthSamples: Int
    let width: CGFloat
    let height: CGFloat
    let stripeWidth: CGFloat
    let stripeSpacing: CGFloat
    let color: Color
    var channelLabel: String? = nil // Optional channel label (L or R)
    
    var body: some View {
        Canvas { context, size in
            drawClipSectionWaveform(in: context, size: size)
        }
        .frame(width: width, height: height)
        .overlay(
            // Show channel label if provided
            Group {
                if let label = channelLabel {
                    Text(label)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(2)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(2)
                        .position(x: 8, y: 8)
                }
            }
        )
    }
    
    private func drawClipSectionWaveform(in context: GraphicsContext, size: CGSize) {
        guard !samples.isEmpty, clipStartSample >= 0, clipLengthSamples > 0 else { return }
        
        let centerY = size.height / 2.0
        
        // Use smaller stripeWidth and spacing for more detailed visualization
        let effectiveStripeWidth = min(stripeWidth, 1.5)
        let effectiveSpacing = max(0.5, stripeSpacing / 4)
        let barWidth = effectiveStripeWidth + effectiveSpacing
        
        // Calculate how many bars we can fit
        let totalBars = Int(size.width / barWidth) + 1
        
        // Calculate which portion of the original samples to use
        let clipStartRatio = Double(clipStartSample) / Double(totalSamples)
        let clipEndRatio = Double(clipStartSample + clipLengthSamples) / Double(totalSamples)
        
        // Draw the waveform bars
        for i in 0..<totalBars {
            let x = CGFloat(i) * barWidth
            
            // Skip if we're out of bounds
            if x >= size.width {
                continue
            }
            
            // Calculate the position within the clip as a ratio (0.0 to 1.0)
            let positionInClip = Double(i) / Double(totalBars)
            
            // Map this position to the actual sample in the full audio file
            let sampleRatio = clipStartRatio + positionInClip * (clipEndRatio - clipStartRatio)
            let sampleIndex = min(Int(sampleRatio * Double(samples.count)), samples.count - 1)
            
            // Get sample value (normalized to 0.0-1.0 range)
            var sampleValue = abs(samples[sampleIndex])
            sampleValue = min(sampleValue, 1.0) // Cap at 1.0
            
            // Calculate bar height based on sample value
            let barHeight = sampleValue * Float(centerY) * 1.8 // Slightly increase height for visual impact
            
            // Only draw if bar has height
            if barHeight > 0.01 {
                // Draw top part of bar (above center line)
                let topRect = CGRect(
                    x: x,
                    y: centerY - CGFloat(barHeight),
                    width: effectiveStripeWidth + 0.5, // Add a small overlap to prevent gaps
                    height: CGFloat(barHeight)
                )
                
                // Draw bottom part of bar (below center line)
                let bottomRect = CGRect(
                    x: x,
                    y: centerY,
                    width: effectiveStripeWidth + 0.5, // Add a small overlap to prevent gaps
                    height: CGFloat(barHeight)
                )
                
                // Create paths for the bars
                let topPath = Path(topRect)
                let bottomPath = Path(bottomRect)
                
                // Draw the bars with the appropriate color
                context.fill(topPath, with: .color(color))
                context.fill(bottomPath, with: .color(color))
            }
        }
    }
}
