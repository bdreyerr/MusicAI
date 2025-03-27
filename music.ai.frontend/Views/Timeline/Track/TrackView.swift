import SwiftUI
import Foundation
// Import our drag and drop manager
// no module import needed for AudioDragDropViewModel since it's part of our project

/// View for an individual track in the timeline
struct TrackView: View {
    let track: Track
    @ObservedObject var state: TimelineStateViewModel
    @ObservedObject var projectViewModel: ProjectViewModel
    @ObservedObject var trackViewModel: TrackViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var menuCoordinator: MenuCoordinator
    @StateObject private var dragDropViewModel = AudioDragDropViewModel.shared
    let width: CGFloat
    
    // Computed property to access the MIDI view model
    private var midiViewModel: MidiViewModel {
        return projectViewModel.midiViewModel
    }
    
    // Computed property to access the Audio view model
    private var audioViewModel: AudioViewModel {
        return projectViewModel.audioViewModel
    }
    
    // State for drop handling
    @State private var isTargeted: Bool = false
    @State private var dropLocation: CGPoint = .zero
    
    // State for track color picker
    @State private var showingTrackColorPicker: Bool = false
    
    // Initialize with track's current state
    init(track: Track, state: TimelineStateViewModel, projectViewModel: ProjectViewModel, width: CGFloat) {
        self.track = track
        self.state = state
        self.projectViewModel = projectViewModel
        self.width = width
        
        // Get the track view model from the manager
        self._trackViewModel = ObservedObject(wrappedValue: projectViewModel.trackViewModelManager.viewModel(for: track))
    }
    
    var body: some View {
        // Track content section (scrollable) - fill the entire height
        ZStack(alignment: .topLeading) {
            // Track borders only (no background fill to allow grid to show through)
            Rectangle()
                .stroke(themeManager.secondaryBorderColor, lineWidth: 0.5)
                .background(Color.clear)
                .allowsHitTesting(false) // Don't block clicks on the background
                .zIndex(0)
            
            // Track content based on type
            Group {
                if track.type == .midi {
                    // MIDI clips
                    ForEach(track.midiClips) { clip in
                        MidiClipView(
                            clip: clip,
                            track: track,
                            state: state,
                            projectViewModel: projectViewModel,
                            trackViewModel: trackViewModel
                        )
                        .environmentObject(themeManager)
                        .environmentObject(menuCoordinator)
                    }
                } else if track.type == .audio {
                    // Audio clips
                    ForEach(track.audioClips) { clip in
                        AudioClipView(
                            clip: clip,
                            track: track,
                            state: state,
                            projectViewModel: projectViewModel,
                            trackViewModel: trackViewModel
                        )
                        .environmentObject(themeManager)
                        .environmentObject(menuCoordinator)
                    }
                }
            }
            
            // Selection overlay
            TimelineSelectionOverlay(
                state: state,
                projectViewModel: projectViewModel,
                track: track
            )
            .environmentObject(themeManager)
            .zIndex(5) // Ensure selection overlay is above other elements
            .id("selection-overlay-\(track.id)-\(state.selectionActive)-\(state.selectionStartBeat)-\(state.selectionEndBeat)") // Force redraw when selection changes
            
            // Transparent overlay for handling clicks and drags
            TimelineSelector(
                projectViewModel: projectViewModel,
                state: state,
                track: track
            )
            .contentShape(Rectangle()) // Ensure the entire area is clickable
            .zIndex(20) // Ensure selector is at the very top to receive all interactions
            
            // Drop target indicator
            if isTargeted {
                Rectangle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: 4, height: trackViewModel.isCollapsed ? 30 : track.height)
                    .offset(x: dropLocation.x)
            }
        }
        .frame(width: width, height: trackViewModel.isCollapsed ? 30 : track.height)
        .background(Color.clear) // Make background transparent to let grid show through
        .contextMenu { trackContextMenu }
        .popover(isPresented: $showingTrackColorPicker) {
            VStack(spacing: 10) {
                Text("Track Color")
                    .font(.headline)
                    .padding(.top, 8)
                
                ColorPicker("Select Color", selection: Binding(
                    get: { trackViewModel.effectiveColor },
                    set: { newColor in
                        trackViewModel.updateTrackColor(newColor)
                    }
                ))
                .padding(.horizontal)
                
                Button("Reset to Default") {
                    trackViewModel.updateTrackColor(nil)
                    showingTrackColorPicker = false
                }
                .padding(.bottom, 8)
            }
            .frame(width: 250)
            .padding(8)
        }
        .alert(isPresented: $trackViewModel.showingDeleteConfirmation) {
            Alert(
                title: Text("Delete Track"),
                message: Text("Are you sure you want to delete this track? This cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    trackViewModel.deleteTrack()
                },
                secondaryButton: .cancel()
            )
        }
        .onDrop(of: [
            "public.file-url",
            "com.microsoft.waveform-audio", 
            "public.mp3", 
            "public.audio",
            "com.music.ai.audiofile",
            "public.data", 
            "public.content", 
            "public.item"
        ], isTargeted: $isTargeted) { providers, location in
            // Check if we can start a drop operation
            if !projectViewModel.interactionManager.startDrop() {
                return false
            }
            
            dropLocation = location
            let result = handleDrop(providers: providers, location: location)
            
            // End the drop operation after a short delay to allow for async processing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                projectViewModel.interactionManager.endDrop()
            }
            
            return result
        }
        .contentShape(Rectangle())
        .onTapGesture { location in
            // Clear any multi-selection when clicking empty space
            state.clearSelectedClips()
            
            // Treat this as normal selection handling
            handleTrackClick(location: location)
        }
        // Apply highlight if this track is selected but keep background transparent
        .overlay(
            ZStack {
                // Selection highlight with transparency
                if projectViewModel.isTrackSelected(track) {
                    Rectangle()
                        .fill(trackViewModel.effectiveColor.opacity(0.1))
                        .allowsHitTesting(false) // Important: Don't block clicks
                }
                
                // Border
                Rectangle()
                    .stroke(projectViewModel.isTrackSelected(track) ? trackViewModel.effectiveColor.opacity(0.5) : Color.clear, lineWidth: 0.5)
                    .allowsHitTesting(false) // Important: Don't block clicks
            }
        )
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var trackContextMenu: some View {
        // Copy and paste options
//        Button("Copy") {
//            menuCoordinator.copySelectedClip()
//        }
//        .keyboardShortcut("c", modifiers: .command)
//        
//        Button("Duplicate") {
//            menuCoordinator.duplicateSelectedClip()
//        }
//        .keyboardShortcut("d", modifiers: .command)
//        
//        Button("Paste") {
//            menuCoordinator.pasteClip()
//        }
//        .keyboardShortcut("v", modifiers: .command)
        
        Divider()
        
        // Create MIDI clip option (only for MIDI tracks and when there's a selection)
        if track.type == .midi && state.hasSelection(trackId: track.id) {
            Button("Create MIDI Clip") {
                midiViewModel.createMidiClipFromSelection()
            }
        }
        
        // Create audio clip option (only for audio tracks and when there's a selection)
        if track.type == .audio && state.hasSelection(trackId: track.id) {
            Button("Create Audio Clip") {
                audioViewModel.createAudioClipFromSelection()
            }
        }
        
        // Add Split option when there's a clip under playhead or a selection
        if (track.type == .midi && !track.midiClips.isEmpty) || (track.type == .audio && !track.audioClips.isEmpty) {
            Button("Split") {
                menuCoordinator.splitClip()
            }
            .keyboardShortcut("e", modifiers: .command)
        }
        
        Divider()
        
        // Enable/Disable option
        Button(trackViewModel.isEnabled ? "Disable Track" : "Enable Track") {
            print("trying to enable / disable track")
            trackViewModel.toggleEnabled()
        }
        
        // Mute option
        Button(trackViewModel.isMuted ? "Unmute Track" : "Mute Track") {
            toggleMute()
        }
        
        // Solo option
        Button(trackViewModel.isSolo ? "Unsolo Track" : "Solo Track") {
            toggleSolo()
        }
        
        // Arm option
        Button(trackViewModel.isArmed ? "Disarm Track" : "Arm for Recording") {
            toggleArmed()
        }
        
        Divider()
        
        // Rename option
        Button("Rename Track") {
            renameTrack()
        }
        
        // Change color option
        Button("Change Color") {
            showingTrackColorPicker = true
        }
        
        // Delete option
        Button("Delete Track", role: .destructive) {
            trackViewModel.showingDeleteConfirmation = true
        }
    }
    
    // Methods for handling track control actions
    private func toggleMute() {
        trackViewModel.toggleMute()
    }
    
    private func toggleSolo() {
        trackViewModel.toggleSolo()
    }
    
    private func toggleArmed() {
        trackViewModel.toggleArmed()
    }
    
    private func updateTrackEnabledState() {
        trackViewModel.toggleEnabled()
    }
    
    private func renameTrack() {
        // Handle rename directly by finding the track and updating its name
        if let index = projectViewModel.tracks.firstIndex(where: { $0.id == track.id }) {
            // Show a popup or alert to get the new name
            let alert = NSAlert()
            alert.messageText = "Rename Track"
            alert.informativeText = "Enter a new name for the track:"
            
            let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
            textField.stringValue = track.name
            alert.accessoryView = textField
            
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                trackViewModel.trackName = textField.stringValue
                trackViewModel.updateTrackName()
            }
        }
    }
    
    private func deleteTrack() {
        trackViewModel.deleteTrack()
    }
    
    private func updateTrackColor(_ color: Color?) {
        trackViewModel.updateTrackColor(color)
    }
    
    // Handle the drop of an audio file
    private func handleDrop(providers: [NSItemProvider], location: CGPoint) -> Bool {
        // Log all providers and their type identifiers for debugging
        print("🔍 EXAMINING PROVIDERS:")
        for (index, provider) in providers.enumerated() {
            print("🔍 Provider \(index) type identifiers: \(provider.registeredTypeIdentifiers)")
        }
        
        // Process audio file URL that might be dropped directly - try this first
        for provider in providers {
            if provider.canLoadObject(ofClass: URL.self) {
                provider.loadObject(ofClass: URL.self) { (urlData, error) in
                    guard error == nil else {
                        print("❌ Error loading URL from provider: \(error!.localizedDescription)")
                        return
                    }
                    
                    guard let url = urlData as? URL, url.isFileURL else {
                        print("❌ Invalid URL or not a file URL")
                        return
                    }
                    
                    // Process the URL on the main thread
                    DispatchQueue.main.async {
                        // Calculate beat position for the drop
                        let xPosition = location.x
                        let beatPosition = xPosition / CGFloat(self.state.effectivePixelsPerBeat)
                        let snappedPosition = self.snapToNearestGridMarker(beatPosition)
                        
                        // Set the beat position in a local variable
                        let dropBeatPosition = snappedPosition
                        
                        // Clear the cached path since we're handling a direct URL drop
                        self.dragDropViewModel.mostRecentDragPath = nil
                        
                        // Cache this new path for future operations
                        self.dragDropViewModel.cacheDragPath(fileName: url.lastPathComponent, path: url.path)
                        
                        // Check if this is an audio track
                        if self.track.type == .audio {
                            // Create audio clip directly on this audio track
                            let success = self.audioViewModel.createAudioClipFromFile(
                                trackId: self.track.id,
                                filePath: url.path,
                                fileName: url.lastPathComponent,
                                startBeat: dropBeatPosition
                            )
                            
                            if success {
                                print("✅ Successfully created audio clip from directly dropped file at beat \(dropBeatPosition)")
                            } else {
                                print("❌ CLIP CREATION FAILED")
                            }
                        } else {
                            // Forward to the first audio track
                            self.ensureAudioTrackExists()
                            
                            if let audioTrack = self.projectViewModel.tracks.first(where: { $0.type == .audio }) {
                                let audioFileData = AudioFileDragData(
                                    name: url.lastPathComponent,
                                    path: url.path,
                                    fileExtension: url.pathExtension,
                                    icon: "music.note"
                                )
                                
                                // Use audio view model to create a clip at a default position
                                let startBeat = 0.0
                                self.audioViewModel.createAudioClipFromFile(
                                    trackId: audioTrack.id,
                                    filePath: url.path,
                                    fileName: url.lastPathComponent,
                                    startBeat: startBeat
                                )
                            }
                        }
                    }
                }
                return true
            }
        }
        
        // Try to handle common item provider types
        for provider in providers {
            // Try to handle with processItemProvider
            for typeId in provider.registeredTypeIdentifiers {
                if typeId.contains("audio") || typeId.contains("mp3") || typeId.contains("wav") {
                    print("⚠️ Attempting to process with type ID: \(typeId)")
                    processItemProvider(provider, typeIdentifier: typeId, at: location)
                    return true
                }
            }
        }
        
        // FALLBACK: Check if we already have a cached path from the most recent drag
        // Only use cached path if we couldn't handle the direct drag from Finder
        if let path = dragDropViewModel.mostRecentDragPath, FileManager.default.fileExists(atPath: path) {
            print("✅ USING CACHED PATH FROM DRAG (FALLBACK): \(path)")
            let fileName = URL(fileURLWithPath: path).lastPathComponent
            
            // Make sure we have an audio track
            if track.type != .audio {
                ensureAudioTrackExists()
                
                if let audioTrack = projectViewModel.tracks.first(where: { $0.type == .audio }) {
                    let audioFileData = AudioFileDragData(
                        name: fileName,
                        path: path,
                        fileExtension: URL(fileURLWithPath: path).pathExtension,
                        icon: "music.note"
                    )
                    
                    // Use audio view model to create a clip at beat 0 (or other default position)
                    let startBeat = 0.0
                    audioViewModel.createAudioClipFromFile(
                        trackId: audioTrack.id,
                        filePath: path,
                        fileName: fileName,
                        startBeat: startBeat
                    )
                    
                    return true
                }
                
                return false
            }
            
            // Calculate beat position for the drop
            let xPosition = location.x
            let beatPosition = xPosition / CGFloat(state.effectivePixelsPerBeat)
            let snappedPosition = snapToNearestGridMarker(beatPosition)
            
            // Set the beat position in a local variable
            let dropBeatPosition = snappedPosition
            
            // Create audio clip at the drop position
            let fileExtension = URL(fileURLWithPath: path).pathExtension
            let success = audioViewModel.createAudioClipFromFile(
                trackId: track.id,
                filePath: path,
                fileName: fileName,
                startBeat: dropBeatPosition
            )
            
            if success {
                print("✅ Successfully created audio clip from dropped file at beat \(dropBeatPosition)")
                return true
            } else {
                print("❌ Failed to create audio clip from dropped file")
                return false
            }
        }
        
        // If we get here, we couldn't handle the drop
        return false
    }
    
    // Ensure there's an audio track to receive the drop
    private func ensureAudioTrackExists() {
        // Check if there's already an audio track
        if projectViewModel.tracks.first(where: { $0.type == .audio }) == nil {
            // Create a new audio track if none exists
            projectViewModel.addTrack(type: .audio)
        }
    }
    
    // Process an item provider with the given type identifier
    private func processItemProvider(_ provider: NSItemProvider, typeIdentifier: String, at location: CGPoint) {
        provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { (data, error) in
            guard error == nil else {
                print("❌ Error loading item: \(error!.localizedDescription)")
                return
            }
            
            print("✅ PROVIDER: Loaded data of type: \(type(of: data))")
            
            // Handle URL data (common for file drops)
            if let urlData = data {
                print("✅ PROVIDER: Got data: \(urlData)")
                
                // Make sure we're on the main thread for UI updates
                DispatchQueue.main.async {
                    // Calculate beat position for the drop
                    let xPosition = location.x
                    let beatPosition = xPosition / CGFloat(self.state.effectivePixelsPerBeat)
                    let snappedPosition = self.snapToNearestGridMarker(beatPosition)
                    
                    // Set the beat position in a local variable
                    let dropBeatPosition = snappedPosition
                    
                    // Forward the drop to the appropriate handler based on data type
                    self.forwardDroppedData(urlData, at: location)
                }
                return
            }
            
            print("❌ PROVIDER: No data received from provider")
        }
    }
    
    // Forward dropped data to the appropriate handler
    private func forwardDroppedData(_ urlData: Any, at location: CGPoint) {
        if let nsurl = urlData as? NSURL, let url = nsurl as URL? {
            print("✅ FORWARDED NSURL: Got \(url.path)")
            DispatchQueue.main.async {
                // Try to create an audio clip from the file
                if self.track.type == .audio {
                    // Use audio view model to create a clip at the dropped position
                    let xPosition = location.x
                    let beatPosition = xPosition / CGFloat(self.state.effectivePixelsPerBeat)
                    let snappedPosition = self.snapToNearestGridMarker(beatPosition)
                    
                    let success = self.audioViewModel.createAudioClipFromFile(
                        trackId: self.track.id,
                        filePath: url.path,
                        fileName: url.lastPathComponent,
                        startBeat: snappedPosition
                    )
                    
                    if success {
                        print("✅ CLIP CREATED: Successfully created audio clip from dropped file at beat \(snappedPosition)")
                    } else {
                        print("❌ CLIP CREATION FAILED")
                    }
                } else {
                    print("⚠️ Not an audio track, forwarding to first audio track...")
                    self.ensureAudioTrackExists()
                    
                    // Find the first audio track
                    if let audioTrack = self.projectViewModel.tracks.first(where: { $0.type == .audio }) {
                        print("✅ CREATING CLIP ON FORWARDED TRACK: \(audioTrack.name)")
                        
                        // Use audio view model to create a clip at beat 0 (or other default position)
                        let startBeat = 0.0
                        let success = self.audioViewModel.createAudioClipFromFile(
                            trackId: audioTrack.id,
                            filePath: url.path,
                            fileName: url.lastPathComponent,
                            startBeat: startBeat
                        )
                        
                        if success {
                            print("✅ CLIP CREATED ON FORWARDED TRACK: Successfully created audio clip from dropped file")
                        } else {
                            print("❌ CLIP CREATION FAILED ON FORWARDED TRACK")
                        }
                    }
                }
            }
            return
        }
        
        if let url = urlData as? URL, url.isFileURL {
            print("✅ FORWARDED FILE URL: Got \(url.path)")
            DispatchQueue.main.async {
                // Find the first audio track
                if let audioTrack = self.projectViewModel.tracks.first(where: { $0.type == .audio }) {
                    print("✅ CREATING CLIP ON FORWARDED TRACK: \(audioTrack.name)")
                    
                    // Use audio view model to create a clip at beat 0 (or other default position)
                    let startBeat = 0.0
                    let success = self.audioViewModel.createAudioClipFromFile(
                        trackId: audioTrack.id,
                        filePath: url.path,
                        fileName: url.lastPathComponent,
                        startBeat: startBeat
                    )
                    
                    if success {
                        print("✅ CLIP CREATED ON FORWARDED TRACK: Successfully created audio clip from dropped file")
                    } else {
                        print("❌ CLIP CREATION FAILED ON FORWARDED TRACK")
                    }
                }
            }
        } else {
            print("❌ UNEXPECTED DATA during forwarding: \(type(of: urlData))")
        }
    }
    
    // Snap a beat position to the nearest grid marker
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
    
    // Handle clicks on empty areas of the track
    private func handleTrackClick(location: CGPoint) {
        // Convert the click location to beats
        let clickBeat = Double(location.x) / state.effectivePixelsPerBeat
        
        // Select the track
        projectViewModel.selectTrack(id: track.id)
        
        // If shift key is pressed, extend or start selection
        if NSEvent.modifierFlags.contains(.shift) {
            if !state.selectionActive {
                // Start a new selection from the click position
                state.startSelection(at: clickBeat, trackId: track.id)
            } else {
                // Extend the existing selection to the click position
                state.updateSelection(to: clickBeat)
            }
        } else {
            // Start a new selection at the click position
            state.startSelection(at: clickBeat, trackId: track.id)
            state.updateSelection(to: clickBeat)
        }
        
        // Move playhead to click position
        projectViewModel.seekToBeat(clickBeat)
    }
}

// MARK: - Helper Views

// TrackGridView has been replaced by SharedGridView for better performance
// The grid is now rendered once for all tracks in the SharedTracksGridContainer

/// View for displaying the drop target indicator
struct DropTargetIndicator: View {
    let track: Track
    @ObservedObject var trackViewModel: TrackViewModel
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        Rectangle()
            .fill(trackViewModel.effectiveColor.opacity(0.3))
            .frame(width: width, height: height)
            .overlay(
                Rectangle()
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 2, dash: [5, 5])
                    )
                    .foregroundColor(trackViewModel.effectiveColor)
            )
            .allowsHitTesting(false) // Don't block other interactions
    }
}

#Preview {
    TrackView(
        track: Track.samples[0],
        state: TimelineStateViewModel(),
        projectViewModel: ProjectViewModel(),
        width: 800
    )
    .environmentObject(ThemeManager())
} 
