import SwiftUI
import Foundation
// Import our drag and drop manager
// no module import needed for AudioDragDropViewModel since it's part of our project

/// View for an individual track in the timeline
struct TrackView: View {
    let track: Track
    @ObservedObject var state: TimelineStateViewModel
    @ObservedObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var themeManager: ThemeManager
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
    
    // State to track local changes before updating the model
    @State private var isMuted: Bool
    @State private var isSolo: Bool
    @State private var isArmed: Bool
    
    // State for drop handling
    @State private var isTargeted: Bool = false
    @State private var dropLocation: CGPoint = .zero
    
    // Static cache of known file paths
    private static var knownAudioFilePaths: [String: String] = [
        "808 0": "/Users/bendreyer/Documents/Ableton/Samples/a y m n Selects vol.1/02 808_s/808 0.wav",
        "808 0.wav": "/Users/bendreyer/Documents/Ableton/Samples/a y m n Selects vol.1/02 808_s/808 0.wav",
        "Kick 0": "/Users/bendreyer/Documents/Ableton/Samples/a y m n Selects vol.1/03 Kicks/Kick 0.wav",
        "Kick 0.wav": "/Users/bendreyer/Documents/Ableton/Samples/a y m n Selects vol.1/03 Kicks/Kick 0.wav",
        "808 5": "/Users/bendreyer/Documents/Ableton/Samples/a y m n Selects vol.1/02 808_s/808 5.wav",
        "808 5.wav": "/Users/bendreyer/Documents/Ableton/Samples/a y m n Selects vol.1/02 808_s/808 5.wav"
    ]
    
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
            trackGridLines
            
            // Track content based on type
            Group {
                if track.type == .midi {
                    // MIDI clips
                    ForEach(track.midiClips) { clip in
                        MidiClipView(
                            clip: clip,
                            track: track,
                            state: state,
                            projectViewModel: projectViewModel
                        )
                        .environmentObject(themeManager)
                    }
                } else if track.type == .audio {
                    // Audio clips
                    ForEach(track.audioClips) { clip in
                        AudioClipView(
                            clip: clip,
                            track: track,
                            state: state,
                            projectViewModel: projectViewModel
                        )
                        .environmentObject(themeManager)
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
            .zIndex(10) // Ensure selector is at the top to receive all interactions
            
            // Drop target indicator
            if isTargeted {
                Rectangle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: 4, height: track.height)
                    .offset(x: dropLocation.x)
            }
        }
        .frame(width: width, height: track.height)
        .background(trackBackground)
        .contextMenu { trackContextMenu }
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
        // Apply highlight if this track is selected
        .overlay(
            Rectangle()
                .stroke(projectViewModel.isTrackSelected(track) ? themeManager.accentColor : Color.clear, lineWidth: 2)
        )
    }
    
    // MARK: - View Components
    
    private var trackBackground: some View {
        Rectangle()
            .fill(themeManager.tertiaryBackgroundColor)
            // Add a subtle highlight when the track is selected
            .overlay(
                Rectangle()
                    .stroke(projectViewModel.isTrackSelected(track) ? themeManager.accentColor : Color.clear, lineWidth: 2)
                    .opacity(projectViewModel.isTrackSelected(track) ? 0.5 : 0)
            )
            // Add thin border around the track for visual separation
            .overlay(
                Rectangle()
                    .strokeBorder(themeManager.secondaryBorderColor, lineWidth: 0.5)
            )
            .zIndex(0) // Background at the bottom
    }
    
    private var trackGridLines: some View {
        TrackGridView(
            state: state,
            projectViewModel: projectViewModel,
            themeManager: themeManager,
            scrollOffset: projectViewModel.timelineState?.scrollOffset ?? .zero,
            viewportWidth: width
        )
        .id("track-grid-\(themeManager.themeChangeIdentifier)") // Force redraw when theme changes
        .zIndex(1) // Grid lines above background
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
    private func handleDrop(providers: [NSItemProvider], location: CGPoint) -> Bool {
        // Log all providers and their type identifiers for debugging
        print("🔍 EXAMINING PROVIDERS:")
        for (index, provider) in providers.enumerated() {
            print("🔍 Provider \(index) type identifiers: \(provider.registeredTypeIdentifiers)")
        }
        
        // Check if we already have a cached path from the most recent drag
        if let path = dragDropViewModel.mostRecentDragPath, FileManager.default.fileExists(atPath: path) {
            print("✅ USING CACHED PATH FROM DRAG: \(path)")
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
                    
                    // Process the audio file on the audio track
                    DispatchQueue.main.async {
                        let beatPosition = Double(location.x) / self.state.effectivePixelsPerBeat
                        let snappedBeatPosition = self.snapToNearestGridMarker(beatPosition)
                        
                        self.audioViewModel.createAudioClipFromFile(
                            trackId: audioTrack.id,
                            filePath: path,
                            fileName: fileName,
                            startBeat: snappedBeatPosition
                        )
                        
                        // Register the successful drop in the view model
                        self.dragDropViewModel.registerDropCompleted(fileName: fileName, path: path, successful: true)
                    }
                    return true
                }
            } else {
                // We have an audio track, process directly
                let audioFileData = AudioFileDragData(
                    name: fileName,
                    path: path,
                    fileExtension: URL(fileURLWithPath: path).pathExtension,
                    icon: "music.note"
                )
                
                self.processAudioFileData(audioFileData, at: location)
                
                // Register the successful drop in the view model
                dragDropViewModel.registerDropCompleted(fileName: fileName, path: path, successful: true)
                return true
            }
        }
        
        // Make sure we have an audio track to receive the drop
        if track.type != .audio {
            print("⚠️ DROP ON NON-AUDIO TRACK: Ensuring audio track exists")
            ensureAudioTrackExists()
            
            // Since the current track isn't an audio track, we need to process the drop differently
            if let audioTrack = projectViewModel.tracks.first(where: { $0.type == .audio }) {
                print("✅ FORWARDING DROP: to audio track '\(audioTrack.name)'")
                processDropForAudioTrack(providers: providers, location: location)
                return true
            } else {
                print("❌ DROP REJECTED: No audio track available after ensure attempt")
                return false
            }
        }
        
        // Try handling the drop with various type identifiers in order of preference
        
        // 0. First try with waveform audio (direct audio file)
        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier("com.microsoft.waveform-audio") }) {
            print("✅ ATTEMPTING: Direct waveform audio approach")
            
            // Try to get the file path from the provider's identity
            if let fileName = provider.suggestedName, !fileName.isEmpty {
                print("✅ GOT FILENAME FROM PROVIDER: \(fileName)")
                
                // Get the drag data from our sidebar for this file
                if let filePath = findFilePath(for: fileName, from: providers) {
                    print("✅ FOUND PATH for \(fileName): \(filePath)")
                    
                    // Create the audio file data
                    let audioFileData = AudioFileDragData(
                        name: fileName,
                        path: filePath,
                        fileExtension: URL(fileURLWithPath: filePath).pathExtension,
                        icon: "music.note"
                    )
                    
                    // Process the audio file data
                    self.processAudioFileData(audioFileData, at: location)
                    return true
                }
            }
            
            // Try to extract file information from any text providers
            if let textProvider = providers.first(where: { $0.hasItemConformingToTypeIdentifier("public.text") }) {
                print("✅ FOUND TEXT PROVIDER, trying to extract file path")
                
                // Create a semaphore to wait for the async operation to complete
                let semaphore = DispatchSemaphore(value: 0)
                var extractedPath: String? = nil
                
                textProvider.loadItem(forTypeIdentifier: "public.text", options: nil) { (itemData, error) in
                    defer { semaphore.signal() }
                    
                    if let error = error {
                        print("❌ ERROR loading text: \(error.localizedDescription)")
                        return
                    }
                    
                    if let string = itemData as? String {
                        print("✅ GOT TEXT PATH: \(string)")
                        extractedPath = string
                    } else if let data = itemData as? Data, let string = String(data: data, encoding: .utf8) {
                        print("✅ GOT TEXT PATH FROM DATA: \(string)")
                        extractedPath = string
                    }
                }
                
                // Wait for the load to complete (but not too long)
                _ = semaphore.wait(timeout: .now() + 0.5)
                
                if let path = extractedPath, !path.isEmpty {
                    // We have a path, let's try to use it
                    print("✅ USING EXTRACTED PATH: \(path)")
                    let fileName = URL(fileURLWithPath: path).lastPathComponent
                    
                    let audioFileData = AudioFileDragData(
                        name: fileName,
                        path: path,
                        fileExtension: URL(fileURLWithPath: path).pathExtension,
                        icon: "music.note"
                    )
                    
                    self.processAudioFileData(audioFileData, at: location)
                    return true
                }
            }
            
            // Use the most recent drag path from the view model
            if let lastDragPath = dragDropViewModel.mostRecentDragPath, FileManager.default.fileExists(atPath: lastDragPath) {
                let fileName = URL(fileURLWithPath: lastDragPath).lastPathComponent
                let fileExtension = URL(fileURLWithPath: lastDragPath).pathExtension
                
                print("✅ USING MOST RECENT DRAG PATH: \(lastDragPath)")
                let audioFileData = AudioFileDragData(
                    name: fileName,
                    path: lastDragPath,
                    fileExtension: fileExtension,
                    icon: "music.note"
                )
                self.processAudioFileData(audioFileData, at: location)
                return true
            }
            
            // Last resort: Try direct loading with the waveform audio type
            print("⚠️ TRYING DIRECT LOADING: with waveform audio")
            provider.loadItem(forTypeIdentifier: "com.microsoft.waveform-audio", options: nil) { (loadedItem, error) in
                if let error = error {
                    print("❌ ERROR loading waveform audio: \(error.localizedDescription)")
                    return
                }
                
                print("✅ LOADED WAVEFORM AUDIO: Type: \(type(of: loadedItem))")
                
                if let url = loadedItem as? URL, url.isFileURL {
                    print("✅ GOT DIRECT URL: \(url.path)")
                    let audioFileData = AudioFileDragData(
                        name: url.lastPathComponent,
                        path: url.path,
                        fileExtension: url.pathExtension,
                        icon: "music.note"
                    )
                    self.processAudioFileData(audioFileData, at: location)
                } else {
                    print("❌ UNEXPECTED WAVEFORM DATA: \(loadedItem.debugDescription)")
                }
            }
            
            return true
        }
        
        // 1. Next, try with public.file-url
        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier("public.file-url") }) {
            print("✅ ATTEMPTING: Direct file URL approach")
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (urlData, error) in
                if let error = error {
                    print("❌ ERROR loading file URL: \(error.localizedDescription)")
                    return
                }
                
                if let url = urlData as? URL, url.isFileURL {
                    print("✅ SUCCESS: Got file URL directly: \(url.path)")
                    // Extract file details
                    let fileName = url.lastPathComponent
                    let path = url.path
                    
                    // Create audio file data
                    let audioFileData = AudioFileDragData(
                        name: fileName,
                        path: path,
                        fileExtension: url.pathExtension,
                        icon: "music.note"
                    )
                    
                    // Cache this path for future use
                    self.dragDropViewModel.cacheDragPath(fileName: fileName, path: path)
                    self.processAudioFileData(audioFileData, at: location)
                    self.dragDropViewModel.registerDropCompleted(fileName: fileName, path: path, successful: true)
                } else if let urlString = urlData as? String, urlString.hasPrefix("file://") {
                    // Sometimes the URL comes as a string
                    print("⚠️ GOT FILE URL AS STRING: \(urlString)")
                    if let url = URL(string: urlString), url.isFileURL {
                        // Extract file details
                        let fileName = url.lastPathComponent
                        let path = url.path
                        
                        // Create audio file data
                        let audioFileData = AudioFileDragData(
                            name: fileName,
                            path: path,
                            fileExtension: url.pathExtension,
                            icon: "music.note"
                        )
                        
                        // Cache this path for future use
                        self.dragDropViewModel.cacheDragPath(fileName: fileName, path: path)
                        self.processAudioFileData(audioFileData, at: location)
                        self.dragDropViewModel.registerDropCompleted(fileName: fileName, path: path, successful: true)
                    }
                } else {
                    print("❌ UNEXPECTED DATA: Received data type: \(type(of: urlData))")
                }
            }
            return true
        }
        
        // 2. Try with our custom type identifier
        let customTypeIdentifier = "com.music.ai.audiofile"
        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(customTypeIdentifier) }) {
            print("✅ FOUND PROVIDER: Using provider with \(customTypeIdentifier)")
            return processItemProvider(provider, typeIdentifier: customTypeIdentifier, at: location)
        }
        
        // 3. Then try other common type identifiers
        for typeId in ["public.data", "public.content", "public.item"] {
            if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(typeId) }) {
                print("⚠️ FALLBACK: Using provider with \(typeId)")
                return processItemProvider(provider, typeIdentifier: typeId, at: location)
            }
        }
        
        // If no suitable provider is found, try to handle the first provider anyway as a last resort
        if let firstProvider = providers.first {
            print("⚠️ LAST RESORT: Trying first provider with no specific type")
            // Try to get any loadable representation
            for typeId in firstProvider.registeredTypeIdentifiers {
                print("⚠️ ATTEMPTING WITH: \(typeId)")
                return processItemProvider(firstProvider, typeIdentifier: typeId, at: location)
            }
        }
        
        print("❌ DROP REJECTED: No suitable provider found")
        return false
    }
    
    // Helper function to find a file path from a file name
    private func findFilePath(for fileName: String, from providers: [NSItemProvider]) -> String? {
        // Check if we have a cached path for this file name
        if let path = dragDropViewModel.getDraggedPath(for: fileName), FileManager.default.fileExists(atPath: path) {
            print("✅ FOUND CACHED PATH: \(path)")
            return path
        }
        
        // Check if the file name is a known file path
        if let path = Self.knownAudioFilePaths[fileName], FileManager.default.fileExists(atPath: path) {
            print("✅ FOUND KNOWN PATH: \(path)")
            return path
        }
        
        // Try to use AudioDragDropViewModel's findFilePath method
        if let path = dragDropViewModel.findFilePath(for: fileName), FileManager.default.fileExists(atPath: path) {
            print("✅ FOUND PATH USING AudioDragDropViewModel: \(path)")
            return path
        }
        
        // Check the pasteboard for a file URL
        if let url = NSPasteboard.general.readObjects(forClasses: [NSURL.self], options: nil)?.first as? URL,
           url.isFileURL,
           FileManager.default.fileExists(atPath: url.path) {
            print("✅ FOUND PATH FROM PASTEBOARD: \(url.path)")
            return url.path
        }
        
        print("❌ COULD NOT FIND PATH FOR: \(fileName)")
        return nil
    }
    
    // Process an item provider to extract the audio file data
    private func processItemProvider(_ itemProvider: NSItemProvider, typeIdentifier: String, at location: CGPoint) -> Bool {
        print("🔄 PROCESSING: Provider with type \(typeIdentifier)")
        
        // Make sure we have at least one audio track
        ensureAudioTrackExists()
        
        // Log the type identifier for debugging
        print("🔄 Processing provider with type identifier: \(typeIdentifier)")
        
        // Special handling for waveform audio
        if typeIdentifier == "com.microsoft.waveform-audio" {
            print("🔊 PROCESSING WAVEFORM AUDIO")
            
            // Try to get the file name from the provider
            if let fileName = itemProvider.suggestedName, !fileName.isEmpty {
                print("✅ GOT FILENAME: \(fileName)")
                
                // Try using the AudioDragDropViewModel to find the path
                if let filePath = dragDropViewModel.findFilePath(for: fileName) {
                    print("✅ FOUND PATH via view model for \(fileName): \(filePath)")
                    
                    // Create audio file data
                    let audioFileData = AudioFileDragData(
                        name: fileName,
                        path: filePath,
                        fileExtension: URL(fileURLWithPath: filePath).pathExtension,
                        icon: "music.note"
                    )
                    
                    // Process the audio file
                    self.processAudioFileData(audioFileData, at: location)
                    
                    // Register successful drop
                    dragDropViewModel.registerDropCompleted(fileName: fileName, path: filePath, successful: true)
                    return true
                } else {
                    // If the view model couldn't find it, try our local method
                    if let filePath = findFilePath(for: fileName, from: [itemProvider]) {
                        print("✅ FOUND PATH via local method for \(fileName): \(filePath)")
                        
                        // Create audio file data
                        let audioFileData = AudioFileDragData(
                            name: fileName,
                            path: filePath,
                            fileExtension: URL(fileURLWithPath: filePath).pathExtension,
                            icon: "music.note"
                        )
                        
                        // Process the audio file
                        self.processAudioFileData(audioFileData, at: location)
                        
                        // Cache this path for future use
                        dragDropViewModel.cacheDragPath(fileName: fileName, path: filePath)
                        dragDropViewModel.registerDropCompleted(fileName: fileName, path: filePath, successful: true)
                        return true
                    }
                }
            }
            
            // Try direct loading with text representation to get file path
            let semaphore = DispatchSemaphore(value: 0)
            var filePath: String? = nil
            
            if itemProvider.hasItemConformingToTypeIdentifier("public.text") {
                itemProvider.loadItem(forTypeIdentifier: "public.text", options: nil) { (item, error) in
                    defer { semaphore.signal() }
                    
                    if let string = item as? String, string.hasPrefix("/") {
                        print("✅ GOT FILE PATH FROM TEXT: \(string)")
                        filePath = string
                    } else if let data = item as? Data, let string = String(data: data, encoding: .utf8), string.hasPrefix("/") {
                        print("✅ GOT FILE PATH FROM TEXT DATA: \(string)")
                        filePath = string
                    }
                }
                
                // Wait briefly for the async operation
                _ = semaphore.wait(timeout: .now() + 0.3)
                
                if let path = filePath {
                    let fileName = URL(fileURLWithPath: path).lastPathComponent
                    let fileExt = URL(fileURLWithPath: path).pathExtension
                    
                    let audioFileData = AudioFileDragData(
                        name: fileName,
                        path: path,
                        fileExtension: fileExt,
                        icon: "music.note"
                    )
                    
                    // Cache this path for future use
                    dragDropViewModel.cacheDragPath(fileName: fileName, path: path)
                    self.processAudioFileData(audioFileData, at: location)
                    dragDropViewModel.registerDropCompleted(fileName: fileName, path: path, successful: true)
                    return true
                }
            }
            
            // Try to get path from cached drag path in the view model
            if let path = dragDropViewModel.mostRecentDragPath, FileManager.default.fileExists(atPath: path) {
                let fileName = URL(fileURLWithPath: path).lastPathComponent
                let fileExt = URL(fileURLWithPath: path).pathExtension
                
                print("✅ USING MOST RECENT DRAG PATH: \(path)")
                let audioFileData = AudioFileDragData(
                    name: fileName,
                    path: path,
                    fileExtension: fileExt,
                    icon: "music.note"
                )
                
                self.processAudioFileData(audioFileData, at: location)
                dragDropViewModel.registerDropCompleted(fileName: fileName, path: path, successful: true)
                return true
            }
            
            // Last resort: Try direct loading with the waveform audio type
            print("⚠️ TRYING DIRECT LOADING: with waveform audio")
            
            // Try direct loading 
            itemProvider.loadItem(forTypeIdentifier: "com.microsoft.waveform-audio", options: nil) { (loadedItem, error) in
                if let error = error {
                    print("❌ ERROR loading waveform audio: \(error.localizedDescription)")
                    return
                }
                
                print("✅ LOADED WAVEFORM AUDIO: Type: \(type(of: loadedItem))")
                
                if let url = loadedItem as? URL, url.isFileURL {
                    print("✅ GOT DIRECT URL: \(url.path)")
                    let fileName = url.lastPathComponent
                    let path = url.path
                    
                    let audioFileData = AudioFileDragData(
                        name: fileName,
                        path: path,
                        fileExtension: url.pathExtension,
                        icon: "music.note"
                    )
                    
                    // Cache this path for future use
                    self.dragDropViewModel.cacheDragPath(fileName: fileName, path: path)
                    self.processAudioFileData(audioFileData, at: location)
                    self.dragDropViewModel.registerDropCompleted(fileName: fileName, path: path, successful: true)
                } else {
                    print("❌ UNEXPECTED WAVEFORM DATA: \(loadedItem.debugDescription)")
                }
            }
            
            return true
        }
        
        // Handle file URL type identifier with special case
        if typeIdentifier == "public.file-url" {
            itemProvider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { (urlData, error) in
                if let error = error {
                    print("❌ ERROR loading file URL: \(error.localizedDescription)")
                    return
                }
                
                if let url = urlData as? URL, url.isFileURL {
                    print("✅ SUCCESS: Got file URL directly: \(url.path)")
                    // Extract file details
                    let fileName = url.lastPathComponent
                    let path = url.path
                    
                    // Create audio file data
                    let audioFileData = AudioFileDragData(
                        name: fileName,
                        path: path,
                        fileExtension: url.pathExtension,
                        icon: "music.note"
                    )
                    
                    // Cache this path for future use
                    self.dragDropViewModel.cacheDragPath(fileName: fileName, path: path)
                    
                    // Process the audio file data
                    self.processAudioFileData(audioFileData, at: location)
                    self.dragDropViewModel.registerDropCompleted(fileName: fileName, path: path, successful: true)
                } else if let urlString = urlData as? String, urlString.hasPrefix("file://") {
                    // Sometimes the URL comes as a string
                    print("⚠️ GOT FILE URL AS STRING: \(urlString)")
                    if let url = URL(string: urlString), url.isFileURL {
                        // Extract file details
                        let fileName = url.lastPathComponent
                        let path = url.path
                        
                        // Create audio file data
                        let audioFileData = AudioFileDragData(
                            name: fileName,
                            path: path,
                            fileExtension: url.pathExtension,
                            icon: "music.note"
                        )
                        
                        // Cache this path for future use
                        self.dragDropViewModel.cacheDragPath(fileName: fileName, path: path)
                        
                        // Process the audio file data
                        self.processAudioFileData(audioFileData, at: location)
                        self.dragDropViewModel.registerDropCompleted(fileName: fileName, path: path, successful: true)
                    }
                } else {
                    print("❌ UNEXPECTED DATA: Received data type: \(type(of: urlData))")
                }
            }
            return true
        }
        
        // Load the data from the provider for other type identifiers
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
                
                // Cache this path for future use
                self.dragDropViewModel.cacheDragPath(fileName: fileName, path: filePath)
                
                // Process the audio file data
                self.processAudioFileData(audioFileData, at: location)
                self.dragDropViewModel.registerDropCompleted(fileName: fileName, path: filePath, successful: true)
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
                
                // Cache this path for future use if it exists
                if let path = audioFileData.path, !path.isEmpty {
                    self.dragDropViewModel.cacheDragPath(fileName: audioFileData.name, path: path)
                }
                
                self.processAudioFileData(audioFileData, at: location)
                
                // Register successful drop
                if let path = audioFileData.path, !path.isEmpty {
                    self.dragDropViewModel.registerDropCompleted(fileName: audioFileData.name, path: path, successful: true)
                }
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
        
        if let path = audioFileData.path {
            print("✅ FILE PATH: \(path)")
            
            // Calculate the beat position based on the drop location
            let beatPosition = Double(location.x) / state.effectivePixelsPerBeat
            let snappedBeatPosition = snapToNearestGridMarker(beatPosition)
            print("✅ DROP POSITION: Beat position \(beatPosition), snapped to \(snappedBeatPosition)")
            
            // Check if file exists
            var hasSecurityAccess = false
            if FileManager.default.fileExists(atPath: path) {
                print("✅ FILE EXISTS: \(path)")
                
                // In a sandboxed app, try to get security-scoped access
                hasSecurityAccess = dragDropViewModel.startAccessingFile(at: path)
                if hasSecurityAccess {
                    print("✅ SECURITY ACCESS GRANTED: File can be accessed")
                } else {
                    print("ℹ️ NO SECURITY ACCESS NEEDED OR AVAILABLE: Using standard file access")
                }
                
                // Create the audio clip on the main thread
                DispatchQueue.main.async {
                    print("✅ CREATING CLIP: From file at path: \(path)")
                    print("✅ TRACK ID: \(self.track.id)")
                    print("✅ TRACK TYPE: \(self.track.type)")
                    
                    let result = self.audioViewModel.createAudioClipFromFile(
                        trackId: self.track.id,
                        filePath: path,
                        fileName: audioFileData.name,
                        startBeat: snappedBeatPosition
                    )
                    
                    // If we had security access, release it
                    if hasSecurityAccess {
                        self.dragDropViewModel.stopAccessingFile(at: path)
                    }
                    
                    if result {
                        print("✅ CLIP CREATED: Successfully created audio clip from dropped file: \(audioFileData.name)")
                    } else {
                        print("❌ CLIP CREATION FAILED: Could not create audio clip from dropped file")
                    }
                }
            } else {
                print("❌ FILE NOT FOUND: \(path)")
            }
        } else {
            print("❌ DROP ERROR: No file path in AudioFileDragData")
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
        } else if state.showHalfNotes {
            // Snap to half notes (2 beats)
            gridDivision = 2.0
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
    
    // Ensure an audio track exists in the project
    private func ensureAudioTrackExists() {
        // Check if this track is an audio track
        if track.type == .audio {
            // Current track is already an audio track, so we're good
            return
        }
        
        // Check if any audio track exists in the project
        let hasAudioTrack = projectViewModel.tracks.contains { $0.type == .audio }
        
        if !hasAudioTrack {
            // No audio track exists, so create one
            print("✅ CREATING: New audio track to receive dropped files")
            projectViewModel.addTrack(name: "Audio Track", type: .audio)
            
            // Since we just added a track, we need to wait for the UI to update
            // before we can access it
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Find the newly created track
                if let newTrackIndex = self.projectViewModel.tracks.firstIndex(where: { $0.type == .audio }) {
                    // Select the new track
                    let trackId = self.projectViewModel.tracks[newTrackIndex].id
                    self.projectViewModel.selectTrack(id: trackId)
                }
            }
        } else {
            // An audio track exists, but this track isn't it
            // Let's select the first audio track
            if let firstAudioTrackIndex = projectViewModel.tracks.firstIndex(where: { $0.type == .audio }) {
                let trackId = projectViewModel.tracks[firstAudioTrackIndex].id
                projectViewModel.selectTrack(id: trackId)
            }
        }
    }
    
    // Process a drop operation for the first available audio track
    private func processDropForAudioTrack(providers: [NSItemProvider], location: CGPoint) {
        // Try to find a provider with public.file-url
        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier("public.file-url") }) {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (urlData, error) in
                if let error = error {
                    print("❌ ERROR forwarding file URL: \(error.localizedDescription)")
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
        } else {
            // Try other approaches for the forwarded drop using processItemProvider
            for typeId in ["com.music.ai.audiofile", "public.data", "public.content", "public.item"] {
                if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(typeId) }) {
                    print("⚠️ FORWARDING using provider with \(typeId)")
                    processItemProvider(provider, typeIdentifier: typeId, at: location)
                    return
                }
            }
            
            print("❌ FORWARDING FAILED: No suitable provider found for forwarding")
        }
    }
}

// MARK: - Helper Views

/// View for displaying the grid lines on a track
struct TrackGridView: View {
    @ObservedObject var state: TimelineStateViewModel
    @ObservedObject var projectViewModel: ProjectViewModel
    let themeManager: ThemeManager
    let scrollOffset: CGPoint
    let viewportWidth: CGFloat
    
    // Add this property to track theme changes
    private var themeIdentifier: String {
        return themeManager.currentTheme.rawValue
    }
    
    // Computed property to determine if we should use simplified rendering during playback
    private var useSimplifiedRendering: Bool {
        return projectViewModel.isPlaying
    }
    
    var body: some View {
        Canvas { context, size in
            // Calculate grid dimensions
            let pixelsPerBeat = state.effectivePixelsPerBeat
            let pixelsPerBar = pixelsPerBeat * Double(projectViewModel.timeSignatureBeats)
            
            // Calculate visible range based on scroll offset
            let startX = scrollOffset.x
            let endX = startX + viewportWidth
            
            // Calculate the total content width in pixels
            let totalContentWidth = size.width
            
            // Calculate the visible bar range
            let startBar = max(0, Int(floor(startX / CGFloat(pixelsPerBar))))
            
            // Calculate the maximum bar index based on content width instead of using a fixed value
            let maxBarIndex = Int(ceil(totalContentWidth / CGFloat(pixelsPerBar)))
            let endBar = min(maxBarIndex, Int(ceil(endX / CGFloat(pixelsPerBar))) + 1) // Add 1 to ensure we render the partial bar at the end
            
            // Determine if we're zoomed out (based on pixels per bar)
            let isZoomedOut = pixelsPerBar < 40
            let isVeryZoomedOut = pixelsPerBar < 20
            let isExtremelyZoomedOut = pixelsPerBar < 10
            
            // During playback, use a slightly simplified grid rendering
            // but maintain visual consistency with non-playing state
            let skipFactor = useSimplifiedRendering ? 
                (isExtremelyZoomedOut ? 2 : (isVeryZoomedOut ? 4 : (isZoomedOut ? 2 : 1))) : 
                (isExtremelyZoomedOut ? 2 : (isVeryZoomedOut ? 4 : (isZoomedOut ? 2 : 1)))
            
            // Minimum pixel distance between grid lines to prevent overcrowding
            // Keep this consistent between playing and paused states
            let minPixelsBetweenLines: CGFloat = 15
            
            // Draw alternating section backgrounds based on zoom level
            drawAlternatingBackgrounds(context: context, size: size, startBar: startBar, endBar: endBar, pixelsPerBar: pixelsPerBar, isZoomedOut: isZoomedOut, isVeryZoomedOut: isVeryZoomedOut, isExtremelyZoomedOut: isExtremelyZoomedOut)
            
            // Draw bar lines
            for barIndex in stride(from: startBar, to: endBar, by: skipFactor) {
                let xPosition = CGFloat(Double(barIndex) * pixelsPerBar)
                
                // Skip if the bar is outside the viewport
                if xPosition + CGFloat(pixelsPerBar) < startX || xPosition > endX {
                    continue
                }
                
                // Draw the bar line
                var path = Path()
                path.move(to: CGPoint(x: xPosition, y: 0))
                path.addLine(to: CGPoint(x: xPosition, y: size.height))
                
                // Use a more prominent color for bar lines
                context.stroke(
                    path,
                    with: .color(themeManager.gridLineColor.opacity(0.7)),
                    lineWidth: 1.0
                )
            }
            
            // Draw beat lines if we're not extremely zoomed out
            // Remove the useSimplifiedRendering condition to ensure beat lines are drawn during playback
            if !isExtremelyZoomedOut {
                // Calculate the beat range
                let startBeat = Double(startBar) * Double(projectViewModel.timeSignatureBeats)
                let endBeat = Double(endBar) * Double(projectViewModel.timeSignatureBeats)
                
                // Draw beat lines (only if we have enough space between them)
                if pixelsPerBeat >= minPixelsBetweenLines {
                    for beatIndex in stride(from: Int(startBeat), to: Int(endBeat), by: 1) {
                        // Skip if this is a bar line (already drawn)
                        if beatIndex % projectViewModel.timeSignatureBeats == 0 {
                            continue
                        }
                        
                        let xPosition = CGFloat(Double(beatIndex) * pixelsPerBeat)
                        
                        // Skip if the beat is outside the viewport
                        if xPosition < startX || xPosition > endX {
                            continue
                        }
                        
                        // Draw the beat line
                        var path = Path()
                        path.move(to: CGPoint(x: xPosition, y: 0))
                        path.addLine(to: CGPoint(x: xPosition, y: size.height))
                        
                        // Use a less prominent color for beat lines
                        context.stroke(
                            path,
                            with: .color(themeManager.gridLineColor.opacity(0.4)),
                            lineWidth: 0.5
                        )
                    }
                }
                
                // Only draw subdivision lines if we're zoomed in enough and not in simplified rendering mode
                if !isZoomedOut && pixelsPerBeat >= minPixelsBetweenLines * 2 {
                    // Determine the subdivision based on zoom level
                    if state.showSixteenthNotes {
                        // Sixteenth notes (0.25 beat)
                        let subdivision = 0.25
                        drawSubdivisionLines(from: startBeat, to: endBeat, by: subdivision, startX: startX, endX: endX, pixelsPerBeat: pixelsPerBeat, context: context, size: size)
                    } else if state.showEighthNotes {
                        // Eighth notes (0.5 beat)
                        let subdivision = 0.5
                        drawSubdivisionLines(from: startBeat, to: endBeat, by: subdivision, startX: startX, endX: endX, pixelsPerBeat: pixelsPerBeat, context: context, size: size)
                    } else if state.showHalfNotes {
                        // Half notes (2 beats)
                        drawHalfNoteLines(from: startBar, to: endBar, startX: startX, endX: endX, pixelsPerBeat: pixelsPerBeat, context: context, size: size)
                    } else {
                        // Default to quarter notes (1 beat)
                        let subdivision = 1.0
                        drawSubdivisionLines(from: startBeat, to: endBeat, by: subdivision, startX: startX, endX: endX, pixelsPerBeat: pixelsPerBeat, context: context, size: size)
                    }
                }
            }
        }
        .drawingGroup(opaque: false) // Use Metal acceleration for better performance
    }
    
    // Draw alternating background sections based on zoom level
    private func drawAlternatingBackgrounds(context: GraphicsContext, size: CGSize, startBar: Int, endBar: Int, pixelsPerBar: Double, isZoomedOut: Bool, isVeryZoomedOut: Bool, isExtremelyZoomedOut: Bool) {
        // Calculate the same skipFactor used for grid lines to ensure perfect alignment
        let skipFactor = useSimplifiedRendering ? 
            (isExtremelyZoomedOut ? 2 : (isVeryZoomedOut ? 4 : (isZoomedOut ? 2 : 1))) : 
            (isExtremelyZoomedOut ? 2 : (isVeryZoomedOut ? 4 : (isZoomedOut ? 2 : 1)))
        
        // Determine section size based on zoom level - match exactly with skipFactor
        let sectionSize: Int
        
        if isExtremelyZoomedOut {
            sectionSize = skipFactor * 2 // Double the skipFactor for extremely zoomed out (typically 4)
        } else if isVeryZoomedOut {
            sectionSize = skipFactor // Match skipFactor for very zoomed out (typically 4)
        } else if isZoomedOut {
            sectionSize = skipFactor // Match skipFactor for zoomed out (typically 2)
        } else {
            sectionSize = 1 // Default to 1 bar for the most zoomed in level
        }
        
        // Extra factor for the most zoomed in view (half-bar sections)
        // Only apply half-bar sections at the most zoomed in level
        let subSections = !isZoomedOut && !isVeryZoomedOut && !isExtremelyZoomedOut ? 2 : 1
        
        // Calculate the stride value and ensure it's not zero
        let strideValue = max(1, sectionSize / subSections)
        
        // Adjust start bar to the nearest section start
        let adjustedStartBar = (startBar / sectionSize) * sectionSize
        
        // For all zoom levels, use the regular alternating pattern but aligned with skipFactor
        for barIndex in stride(from: adjustedStartBar, to: endBar, by: strideValue) {
            // Determine if this should be colored (alternating)
            // Division by strideValue ensures we get the correct alternating pattern
            let shouldColor = (barIndex / strideValue) % 2 == 1
            
            if shouldColor {
                // Calculate section start and width
                let sectionStart = CGFloat(Double(barIndex) * pixelsPerBar)
                let sectionWidth = CGFloat(Double(strideValue) * pixelsPerBar)
                
                // Create rectangle for the section
                let rect = CGRect(x: sectionStart, y: 0, width: sectionWidth, height: size.height)
                let path = Path(rect)
                
                // Fill with alternating color
                context.fill(path, with: .color(themeManager.alternatingGridSectionColor))
            }
        }
    }
    
    // Helper method to draw half note lines
    private func drawHalfNoteLines(from startBar: Int, to endBar: Int, startX: CGFloat, endX: CGFloat, pixelsPerBeat: Double, context: GraphicsContext, size: CGSize) {
        for barIndex in stride(from: startBar, to: endBar, by: 1) {
            let barStartBeat = Double(barIndex) * Double(projectViewModel.timeSignatureBeats)
            
            // For each bar, add half-note markers
            for offset in stride(from: 2.0, to: Double(projectViewModel.timeSignatureBeats), by: 2.0) {
                let beatPosition = barStartBeat + offset
                let xPosition = CGFloat(beatPosition * pixelsPerBeat)
                
                // Skip if outside viewport
                if xPosition < startX || xPosition > endX {
                    continue
                }
                
                // Draw the half note line
                var path = Path()
                path.move(to: CGPoint(x: xPosition, y: 0))
                path.addLine(to: CGPoint(x: xPosition, y: size.height))
                
                context.stroke(
                    path,
                    with: .color(themeManager.gridLineColor.opacity(0.3)),
                    lineWidth: 0.5
                )
            }
        }
    }
    
    // Helper method to draw subdivision lines (16th, 8th, or quarter notes)
    private func drawSubdivisionLines(from startBeat: Double, to endBeat: Double, by subdivision: Double, startX: CGFloat, endX: CGFloat, pixelsPerBeat: Double, context: GraphicsContext, size: CGSize) {
        for beatIndex in stride(from: startBeat, to: endBeat, by: subdivision) {
            // Skip if this is a beat or bar line (already drawn)
            if beatIndex.truncatingRemainder(dividingBy: 1.0) == 0 {
                continue
            }
            
            let xPosition = CGFloat(beatIndex * pixelsPerBeat)
            
            // Skip if the subdivision is outside the viewport
            if xPosition < startX || xPosition > endX {
                continue
            }
            
            // Draw the subdivision line
            var path = Path()
            path.move(to: CGPoint(x: xPosition, y: 0))
            path.addLine(to: CGPoint(x: xPosition, y: size.height))
            
            // Use an even less prominent color for subdivision lines
            context.stroke(
                path,
                with: .color(themeManager.gridLineColor.opacity(0.2)),
                lineWidth: 0.5
            )
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
