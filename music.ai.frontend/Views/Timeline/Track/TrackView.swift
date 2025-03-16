import SwiftUI
import Foundation

/// View for an individual track in the timeline
struct TrackView: View {
    let track: Track
    @ObservedObject var state: TimelineStateViewModel
    @ObservedObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var themeManager: ThemeManager
    let width: CGFloat
    
    // Computed property to access the MIDI view model
    private var midiViewModel: MidiViewModel {
        return projectViewModel.midiViewModel
    }
    
    // Computed property to access the Audio view model
    private var audioViewModel: AudioViewModel {
        return projectViewModel.audioViewModel
    }
    
    // State to track local changes before updating the model
    @State private var isMuted: Bool
    @State private var isSolo: Bool
    @State private var isArmed: Bool
    
    // State for drop handling
    @State private var isTargeted: Bool = false
    @State private var dropLocation: CGPoint = .zero
    
    // Initialize with track's current state
    init(track: Track, state: TimelineStateViewModel, projectViewModel: ProjectViewModel, width: CGFloat) {
        self.track = track
        self.state = state
        self.projectViewModel = projectViewModel
        self.width = width
        
        // Initialize state from track
        _isMuted = State(initialValue: track.isMuted)
        _isSolo = State(initialValue: track.isSolo)
        _isArmed = State(initialValue: track.isArmed)
    }
    
    var body: some View {
        // Track content section (scrollable) - fill the entire height
        ZStack(alignment: .topLeading) {
            // Background with track type color
            trackBackground
            
            // Beat/bar divisions
            TrackGridView(
                state: state,
                projectViewModel: projectViewModel,
                themeManager: themeManager
            )
            .zIndex(1) // Grid lines above background
            
            // Add the selection view
            TimelineSelectionView(
                state: state,
                track: track,
                projectViewModel: projectViewModel
            )
            .environmentObject(themeManager)
            .zIndex(5) // Selection above grid but below clips
            
            // Display clips based on track type
            TrackContentView(
                track: track,
                state: state,
                projectViewModel: projectViewModel
            )
            .environmentObject(themeManager)
            .zIndex(30) // Clips should have the highest z-index
            
            // Add the timeline selector for handling clicks and drags
            TimelineSelector(
                projectViewModel: projectViewModel,
                state: state,
                track: track
            )
            .zIndex(3) // Lower z-index than clips (30) but higher than other elements
            .allowsHitTesting(true) // Ensure the selector can receive clicks
            
            // Drop target indicator (only shown when dragging over an audio track)
            if isTargeted && track.type == .audio {
                DropTargetIndicator(
                    track: track,
                    width: width,
                    height: track.height
                )
                .zIndex(30) // Above everything else
            }
        }
        .frame(width: width, height: track.height) // Use track's height property
        .overlay(trackBorder)
        .opacity((!track.isEnabled || isMuted) && !isSolo ? 0.5 : 1.0) // Dim the track if disabled or muted (unless soloed)
        .contextMenu { trackContextMenu }
        // Add drop handling for audio files (only for audio tracks)
        .if(track.type == .audio) { view in
            view.onDrop(
                of: [
                    "com.music.ai.audiofile",
                    "public.data",
                    "public.content",
                    "public.item"
                ],
                isTargeted: $isTargeted
            ) { providers, location in
                // Debug logs
                print("🎯 DROP DETECTED: Drop event on track: \(track.name)")
                print("🎯 DROP PROVIDERS: \(providers.count) providers available")
                for (index, provider) in providers.enumerated() {
                    print("🎯 DROP PROVIDER \(index): Type identifiers: \(provider.registeredTypeIdentifiers)")
                }
                
                // Store the drop location
                dropLocation = location
                print("🎯 DROP LOCATION: \(location)")
                
                // Select this track
                projectViewModel.selectTrack(id: track.id)
                
                // Handle the dropped item
                return handleDrop(providers: providers, at: location)
            }
        }
    }
    
    // MARK: - View Components
    
    private var trackBackground: some View {
        Rectangle()
            .fill(track.effectiveBackgroundColor(for: themeManager.currentTheme))
            // Add a subtle highlight when the track is selected
            .overlay(
                Rectangle()
                    .stroke(Color.white, lineWidth: projectViewModel.isTrackSelected(track) ? 2 : 0)
                    .opacity(projectViewModel.isTrackSelected(track) ? 0.5 : 0)
            )
            .zIndex(0) // Background at the bottom
    }
    
    private var trackBorder: some View {
        ZStack {
            // Regular border for all tracks
            Rectangle()
                .stroke(themeManager.secondaryBorderColor, lineWidth: 0.5)
                .allowsHitTesting(false)
            
            // Special border for selected track - using a brighter version of the track's color
            if projectViewModel.isTrackSelected(track) {
                Rectangle()
                    .stroke(track.effectiveColor.opacity(0.9), lineWidth: 1.5)
                    .brightness(0.3) // Make the color brighter for better visibility
                    .allowsHitTesting(false)
            }
        }
    }
    
    @ViewBuilder
    private var trackContextMenu: some View {
        // Create MIDI clip option (only for MIDI tracks and when there's a selection)
        if track.type == .midi && state.hasSelection(trackId: track.id) {
            Button("Create MIDI Clip") {
                midiViewModel.createMidiClipFromSelection()
            }
            
            Divider()
        }
        
        // Create audio clip option (only for audio tracks and when there's a selection)
        if track.type == .audio && state.hasSelection(trackId: track.id) {
            Button("Create Audio Clip") {
                audioViewModel.createAudioClipFromSelection()
            }
            
            Divider()
        }
        
        // Track operations
        Button("Rename Track") {
            // Rename functionality would be handled in TrackControlsView
        }
        
        Button("Delete Track") {
            if let index = projectViewModel.tracks.firstIndex(where: { $0.id == track.id }) {
                projectViewModel.removeTrack(at: index)
            }
        }
        
        if track.type == .midi {
            Divider()
            
            Button("Add Instrument") {
                // Add instrument functionality would go here
            }
        }
    }
    
    // Handle the drop of an audio file
    private func handleDrop(providers: [NSItemProvider], at location: CGPoint) -> Bool {
        // Only handle drops on audio tracks
        guard track.type == .audio else {
            print("❌ DROP REJECTED: Track is not an audio track")
            return false
        }
        
        // Check all providers and their type identifiers
        print("🔍 EXAMINING PROVIDERS:")
        for (index, provider) in providers.enumerated() {
            print("🔍 Provider \(index) type identifiers: \(provider.registeredTypeIdentifiers)")
        }
        
        // Try to find a provider with our custom type identifier
        let customTypeIdentifier = "com.music.ai.audiofile"
        let publicDataIdentifier = "public.data"
        
        // First try our custom type
        if let itemProvider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(customTypeIdentifier) }) {
            print("✅ FOUND PROVIDER: Using provider with \(customTypeIdentifier)")
            return processItemProvider(itemProvider, typeIdentifier: customTypeIdentifier, at: location)
        }
        
        // Then try public.data as fallback
        if let itemProvider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(publicDataIdentifier) }) {
            print("⚠️ FALLBACK: Using provider with \(publicDataIdentifier)")
            return processItemProvider(itemProvider, typeIdentifier: publicDataIdentifier, at: location)
        }
        
        print("❌ DROP REJECTED: No suitable provider found")
        return false
    }
    
    // Process an item provider to extract the audio file data
    private func processItemProvider(_ itemProvider: NSItemProvider, typeIdentifier: String, at location: CGPoint) -> Bool {
        print("🔄 PROCESSING: Provider with type \(typeIdentifier)")
        
        // Load the data from the provider
        itemProvider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { (loadedItem, error) in
            if let error = error {
                print("❌ DROP ERROR: Failed to load data from provider: \(error.localizedDescription)")
                return
            }
            
            print("✅ DATA LOADED: Type: \(type(of: loadedItem))")
            
            // Handle different types of data that might be returned
            var data: Data?
            
            if let dataItem = loadedItem as? Data {
                // Direct Data object
                data = dataItem
                print("✅ DATA DIRECT: Received Data object directly")
            } else if let nsData = loadedItem as? NSData {
                // NSData object
                data = Data(referencing: nsData)
                print("✅ DATA CONVERTED: Converted NSData to Data")
            } else if let string = loadedItem as? String, let stringData = string.data(using: .utf8) {
                // String that can be converted to data
                data = stringData
                print("✅ DATA CONVERTED: Converted String to Data")
            } else if let url = loadedItem as? URL, let urlData = try? Data(contentsOf: url) {
                // URL that can be read as data
                data = urlData
                print("✅ DATA CONVERTED: Read Data from URL")
            } else if let fileURL = loadedItem as? URL, fileURL.isFileURL {
                // File URL - try to create AudioFileDragData directly
                let fileName = fileURL.lastPathComponent
                let filePath = fileURL.path
                let fileExtension = fileURL.pathExtension
                
                print("✅ FILE URL: Creating AudioFileDragData directly from file URL: \(filePath)")
                
                let audioFileData = AudioFileDragData(
                    name: fileName,
                    path: filePath,
                    fileExtension: fileExtension,
                    icon: "music.note"
                )
                
                // Process the audio file data
                processAudioFileData(audioFileData, at: location)
                return
            } else {
                print("❌ DROP ERROR: Unsupported data type: \(type(of: loadedItem))")
                
                // Try to extract information about the item for debugging
                if let describable = loadedItem as? CustomStringConvertible {
                    print("❌ ITEM DESCRIPTION: \(describable.description)")
                }
                
                return
            }
            
            // Ensure we have data to decode
            guard let data = data else {
                print("❌ DROP ERROR: Could not convert loaded item to Data")
                return
            }
            
            print("✅ DATA SIZE: \(data.count) bytes")
            
            do {
                let audioFileData = try JSONDecoder().decode(AudioFileDragData.self, from: data)
                processAudioFileData(audioFileData, at: location)
            } catch {
                print("❌ DROP ERROR: Failed to decode AudioFileDragData: \(error.localizedDescription)")
                print("❌ ERROR DETAILS: \(error)")
                
                // Try to print the data as a string for debugging
                if let dataString = String(data: data, encoding: .utf8) {
                    print("❌ DATA CONTENT: \(dataString)")
                }
            }
        }
        
        return true
    }
    
    // Helper method to process the audio file data once we have it
    private func processAudioFileData(_ audioFileData: AudioFileDragData, at location: CGPoint) {
        print("✅ PROCESSING AUDIO FILE: \(audioFileData.name)")
        
        // Calculate the beat position based on the drop location
        let beatPosition = Double(location.x) / state.effectivePixelsPerBeat
        
        // Snap to the nearest grid marker
        let snappedBeatPosition = snapToNearestGridMarker(beatPosition)
        print("✅ DROP POSITION: Beat position \(beatPosition), snapped to \(snappedBeatPosition)")
        
        // Create the audio clip on the main thread
        DispatchQueue.main.async {
            if let path = audioFileData.path {
                print("✅ CREATING CLIP: From file at path: \(path)")
                let success = audioViewModel.createAudioClipFromFile(
                    trackId: track.id,
                    filePath: path,
                    fileName: audioFileData.name,
                    startBeat: snappedBeatPosition
                )
                
                if success {
                    print("✅ CLIP CREATED: Successfully created audio clip from dropped file: \(audioFileData.name)")
                } else {
                    print("❌ CLIP CREATION FAILED: Could not create audio clip from dropped file")
                }
            } else {
                print("❌ DROP ERROR: No file path in AudioFileDragData")
            }
        }
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
            
            // Update the track in the view model
            projectViewModel.updateTrack(at: index, with: updatedTrack)
        }
    }
    
    /// Snaps a raw beat position to the nearest visible grid marker based on the current zoom level
    private func snapToNearestGridMarker(_ rawBeatPosition: Double) -> Double {
        // Determine the smallest visible grid division based on zoom level
        let gridDivision: Double
        
        if state.showSixteenthNotes {
            // Snap to sixteenth notes (0.25 beat)
            gridDivision = 0.25
        } else if state.showEighthNotes {
            // Snap to eighth notes (0.5 beat)
            gridDivision = 0.5
        } else if state.showQuarterNotes {
            // Snap to quarter notes (1 beat)
            gridDivision = 1.0
        } else {
            // When zoomed out all the way, snap to bars
            // For bars, we need to handle differently to ensure we snap to the start of a bar
            let beatsPerBar = Double(projectViewModel.timeSignatureBeats)
            let barIndex = round(rawBeatPosition / beatsPerBar)
            return max(0, barIndex * beatsPerBar) // Ensure we don't go negative
        }
        
        // Calculate the nearest grid marker for beats and smaller divisions
        let nearestGridMarker = round(rawBeatPosition / gridDivision) * gridDivision
        
        return max(0, nearestGridMarker) // Ensure we don't go negative
    }
}

// MARK: - Helper Views

/// View for displaying the grid lines on a track
struct TrackGridView: View {
    @ObservedObject var state: TimelineStateViewModel
    @ObservedObject var projectViewModel: ProjectViewModel
    let themeManager: ThemeManager
    
    var body: some View {
        Canvas { context, size in
            // Calculate grid dimensions
            let pixelsPerBeat = state.effectivePixelsPerBeat
            let pixelsPerBar = pixelsPerBeat * Double(projectViewModel.timeSignatureBeats)
            
            // Number of bars visible
            let visibleBars = 100 // Match the content width calculation
            
            // Vertical grid lines (time divisions)
            for barIndex in 0..<visibleBars {
                let xPosition = CGFloat(Double(barIndex) * pixelsPerBar)
                
                // Bar lines (strong)
                var barPath = Path()
                barPath.move(to: CGPoint(x: xPosition, y: 0))
                barPath.addLine(to: CGPoint(x: xPosition, y: size.height))
                context.stroke(barPath, with: .color(themeManager.gridColor), lineWidth: 1.0)
                
                // Beat lines (medium)
                if state.showQuarterNotes {
                    for beat in 1..<projectViewModel.timeSignatureBeats {
                        let beatX = xPosition + CGFloat(Double(beat) * pixelsPerBeat)
                        var beatPath = Path()
                        beatPath.move(to: CGPoint(x: beatX, y: 0))
                        beatPath.addLine(to: CGPoint(x: beatX, y: size.height))
                        context.stroke(beatPath, with: .color(themeManager.secondaryGridColor), lineWidth: 0.5)
                    }
                }
                
                // Eighth notes (weak)
                if state.showEighthNotes {
                    for beat in 0..<(projectViewModel.timeSignatureBeats * 2) {
                        let eighthX = xPosition + CGFloat(Double(beat) * pixelsPerBeat / 2)
                        if eighthX.truncatingRemainder(dividingBy: CGFloat(pixelsPerBeat)) != 0 {
                            var eighthPath = Path()
                            eighthPath.move(to: CGPoint(x: eighthX, y: 0))
                            eighthPath.addLine(to: CGPoint(x: eighthX, y: size.height))
                            context.stroke(eighthPath, with: .color(themeManager.tertiaryGridColor), lineWidth: 0.5)
                        }
                    }
                }
            }
        }
    }
}

/// View for displaying the content of a track (clips or placeholder text)
struct TrackContentView: View {
    let track: Track
    @ObservedObject var state: TimelineStateViewModel
    @ObservedObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Group {
            if track.type == .midi {
                midiTrackContent
            } else if track.type == .audio {
                audioTrackContent
            } else {
                otherTrackContent
            }
        }
    }
    
    private var midiTrackContent: some View {
        ZStack {
            // Show placeholder text if no clips
            if track.midiClips.isEmpty {
                Text("Right-click to create MIDI clip")
                    .font(.caption)
                    .foregroundColor(themeManager.secondaryTextColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .zIndex(3) // Above selection but below clips
                    .allowsHitTesting(false) // Don't block clicks
            }
            
            // Display MIDI clips if this is a MIDI track
            ForEach(track.midiClips) { clip in
                MidiClipView(
                    clip: clip,
                    track: track,
                    state: state,
                    projectViewModel: projectViewModel
                )
                .environmentObject(themeManager)
                .zIndex(40) // Increase z-index to ensure clips are above all other elements
            }
        }
    }
    
    private var audioTrackContent: some View {
        ZStack {
            // Show placeholder text if no clips
            if track.audioClips.isEmpty {
                Text("Right-click to create audio clip or drag audio files here")
                    .font(.caption)
                    .foregroundColor(themeManager.secondaryTextColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .zIndex(3) // Above selection but below clips
                    .allowsHitTesting(false) // Don't block clicks
            }
            
            // Display audio clips if this is an audio track
            ForEach(track.audioClips) { clip in
                AudioClipView(
                    clip: clip,
                    track: track,
                    state: state,
                    projectViewModel: projectViewModel
                )
                .environmentObject(themeManager)
                .zIndex(40) // Increase z-index to ensure clips are above all other elements
            }
        }
    }
    
    private var otherTrackContent: some View {
        // Placeholder for other track types
        Text("This track type doesn't support clips")
            .font(.caption)
            .foregroundColor(themeManager.secondaryTextColor)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .zIndex(3) // Above selection
            .allowsHitTesting(false) // Don't block clicks
    }
}

/// View for displaying the drop target indicator
struct DropTargetIndicator: View {
    let track: Track
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        Rectangle()
            .fill(track.effectiveColor.opacity(0.3))
            .frame(width: width, height: height)
            .overlay(
                Rectangle()
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 2, dash: [5, 5])
                    )
                    .foregroundColor(track.effectiveColor)
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
