import SwiftUI
import Combine
import AppKit

/// Main timeline view for the DAW application
struct TimelineView: View {
    @StateObject private var timelineState: TimelineStateViewModel
    @State private var startDragY: CGFloat = 0
    @State private var isDragging: Bool = false
    @StateObject private var menuCoordinator = MenuCoordinator()
    @ObservedObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    // Constants
    let rulerHeight: CGFloat = 25
    let defaultTrackHeight: CGFloat = 100 // Default height for new tracks
    let controlsWidth: CGFloat = 200 // Must match TrackView.controlsWidth
    
    // Track grid refresh timing for synchronization
    @State private var lastGridRefreshTime: Date = Date()
    @State private var needsRulerGridSync: Bool = false
    
    // Initialize with project view model
    init(projectViewModel: ProjectViewModel) {
        self.projectViewModel = projectViewModel
        // Initialize the timeline state with _StateObject wrapper
        // This prevents potential didSet triggers during view initialization
        _timelineState = StateObject(wrappedValue: TimelineStateViewModel(projectViewModel: projectViewModel))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                
                // Invisible buttons for keyboard shortcuts
                TimelineButtons(
                    projectViewModel: projectViewModel,
                    timelineState: timelineState
                )
                
                
                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        // Single ScrollView for vertical scrolling
                        ScrollView(.vertical, showsIndicators: false) {
                            // Use a LazyVStack to ensure views are only created when needed
                            LazyVStack(spacing: 0) {
                                // Main content area with tracks and ruler
                                HStack(spacing: 0) {
                                    // Left side: Track controls column
                                    VStack(spacing: 0) {
                                        // Ruler label area (empty space above track controls)
                                        Rectangle()
                                            .fill(themeManager.rulerBackgroundColor)
                                            .frame(width: controlsWidth, height: rulerHeight)
                                        
                                        // Track controls
                                        ForEach(projectViewModel.tracks) { track in
                                            TrackControlsView(
                                                track: track,
                                                projectViewModel: projectViewModel
                                            )
                                            .environmentObject(themeManager)
                                            .frame(width: controlsWidth)
                                        }
                                        
                                        // Add track button
                                        Button(action: showAddTrackMenu) {
                                            HStack {
                                                Image(systemName: "plus.circle.fill")
                                                    .foregroundColor(themeManager.primaryTextColor)
                                                Text("Add Track")
                                                    .foregroundColor(themeManager.primaryTextColor)
                                            }
                                            .padding(8)
                                            .frame(width: controlsWidth, alignment: .leading)
                                        }
                                        .buttonStyle(BorderlessButtonStyle())
                                        .background(themeManager.secondaryBackgroundColor.opacity(0.3))
                                        .padding(.top, 4)
                                        
                                        Spacer()
                                    }
                                    .frame(width: controlsWidth)
                                    
                                    // Right side: Horizontal scroll view containing both ruler and tracks
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        VStack(spacing: 0) {
                                            // New App kit Ruler
                                            AppKitRuler(
                                                state: timelineState,
                                                projectViewModel: projectViewModel,
                                                width: calculateContentWidth(geometry: geometry),
                                                height: rulerHeight)
                                            .environmentObject(themeManager)
                                            .frame(height: rulerHeight)
                                            .background(themeManager.rulerBackgroundColor)
                                            .overlay(
                                                TimelineRulerSelectionIndicator(
                                                    state: timelineState,
                                                    projectViewModel: projectViewModel,
                                                    height: rulerHeight
                                                )
                                                .environmentObject(themeManager)
                                            )
                                            
                                            
                                            // Ruler at the top
                                            //                                                TimelineRuler(
                                            //                                                    state: timelineState,
                                            //                                                    projectViewModel: projectViewModel,
                                            //                                                    width: calculateContentWidth(geometry: geometry),
                                            //                                                    height: rulerHeight
                                            //                                                )
                                            //                                                .environmentObject(themeManager)
                                            //                                                .overlay(
                                            //                                                    TimelineRulerSelectionIndicator(
                                            //                                                        state: timelineState,
                                            //                                                        projectViewModel: projectViewModel,
                                            //                                                        height: rulerHeight
                                            //                                                    )
                                            //                                                    .environmentObject(themeManager)
                                            //                                                )
                                            //                                                .overlay(
                                            //                                                    PlayheadIndicator(
                                            //                                                        currentBeat: projectViewModel.currentBeat,
                                            //                                                        state: timelineState,
                                            //                                                        projectViewModel: projectViewModel,
                                            //                                                        viewportWidth: calculateContentWidth(geometry: geometry)
                                            //                                                    )
                                            //                                                    .environmentObject(themeManager)
                                            //                                                    .frame(height: rulerHeight)
                                            //                                                )
                                            //                                                .frame(height: rulerHeight)
                                            //                                                .background(themeManager.rulerBackgroundColor)
                                            
                                            // Regular tracks grid container
                                            SharedTracksGridContainer(
                                                projectViewModel: projectViewModel,
                                                state: timelineState,
                                                width: calculateContentWidth(geometry: geometry)
                                            )
                                            .environmentObject(themeManager)
                                            //                                                .id("shared-tracks-container-\(themeManager.themeChangeIdentifier)-\(timelineState.contentSizeChangeId)")
                                        }
                                        .frame(width: calculateContentWidth(geometry: geometry))
                                        //                                            .id("timeline-content-\(timelineState.contentSizeChangeId)")
                                    }
                                    .frame(width: geometry.size.width - controlsWidth)
                                }
                            }
                        }
                        
                        // Master track section (outside vertical scroll)
                        HStack(spacing: 0) {
                            // Master track controls
                            MasterTrackControlsView(
                                track: projectViewModel.masterTrack,
                                projectViewModel: projectViewModel
                            )
                            .environmentObject(themeManager)
                            .frame(width: controlsWidth)
                            
                            // Master track content area
                            ScrollView(.horizontal, showsIndicators: false) {
                                Rectangle()
                                    .fill(themeManager.backgroundColor.opacity(0.6))
                                    .frame(width: calculateContentWidth(geometry: geometry), height: 50)
                                    .overlay(
                                        Rectangle()
                                            .stroke(themeManager.secondaryBorderColor, lineWidth: 0.5)
                                    )
                            }
                            .frame(width: geometry.size.width - controlsWidth)
                        }
                        .frame(height: 50)
                    }
                    // Add magnification gesture at the highest level
                    .gesture(
                        MagnificationGesture()
                            .onChanged { scale in
                                DispatchQueue.main.async {
                                    timelineState.handlePinchGesture(scale: scale)
                                }
                            }
                            .onEnded { _ in
                                DispatchQueue.main.async {
                                    timelineState.handlePinchGesture(scale: 1.0)
                                }
                            }
                    )
                    // Add gesture recognizer for right-click
                    .background(
                        EmptyView()
                            .contentShape(Rectangle())
                            .onTapGesture(count: 1, perform: { _ in })
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onEnded { value in
                                        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
                                            showTimelineContextMenu(at: value.location)
                                        }
                                    }
                            )
                    )
                }
                .background(themeManager.backgroundColor)
                
                // Zoom controls in the top right corner
                VStack(spacing: 8) {
                    // Zoom In button
                    Button(action: {
                        zoomIn()
                    }) {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.system(size: 14))
                            .foregroundColor(themeManager.primaryTextColor)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .padding(6)
                    .background(themeManager.secondaryBackgroundColor)
                    .cornerRadius(4)
                    .help("Zoom In")
                    .disabled(timelineState.zoomLevel <= 0)
                    
                    // Zoom Out button
                    Button(action: {
                        zoomOut()
                    }) {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.system(size: 14))
                            .foregroundColor(themeManager.primaryTextColor)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .padding(6)
                    .background(themeManager.secondaryBackgroundColor)
                    .cornerRadius(4)
                    .help("Zoom Out")
                    .disabled(timelineState.zoomLevel >= 6)
                    
                    // Reset Zoom button (to level 3)
                    Button(action: {
                        resetZoom()
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14))
                            .foregroundColor(themeManager.primaryTextColor)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .padding(6)
                    .background(themeManager.secondaryBackgroundColor)
                    .cornerRadius(4)
                    .help("Reset Zoom")
                    .disabled(timelineState.zoomLevel == 3)
                }
                .padding(8)
                
                .onAppear {
                    // Use DispatchQueue.main.async to prevent state updates during view update
                    DispatchQueue.main.async {
                        // Connect the coordinator to our view model
                        menuCoordinator.projectViewModel = projectViewModel
                        // Set the default track height
                        menuCoordinator.defaultTrackHeight = defaultTrackHeight
                        // Connect the timeline state to the project view model
                        projectViewModel.timelineState = timelineState
                        // Connect the timeline state to the MIDI view model
                        projectViewModel.midiViewModel.setTimelineState(timelineState)
                    }
                }
                // Respond to zoom level changes
                .onChange(of: timelineState.zoomLevel) { _, newZoomLevel in
                    // Only adjust position if we're not playing
                    // This prevents interrupting playback when zooming
                    if !projectViewModel.isPlaying {
                        // Ensure the playhead stays at the correct beat position after zoom changes
                        let currentBeat = projectViewModel.currentBeat
                        // This is redundant but ensures the position is updated
                        DispatchQueue.main.async {
                            projectViewModel.seekToBeat(currentBeat)
                        }
                    }
                    
                    // Track grid refresh for synchronization - use async updates
                    DispatchQueue.main.async {
                        self.lastGridRefreshTime = Date()
                        self.needsRulerGridSync = true
                        
                        // Force a redraw of both the grid and ruler with a short delay
                        // to ensure they are in sync after zoom level changes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.timelineState.contentSizeChanged()
                            self.needsRulerGridSync = false
                        }
                    }
                }
                // Clear selection when clicking on the background
                .contentShape(Rectangle())
                .onTapGesture {
                    DispatchQueue.main.async {
                        timelineState.clearSelection()
                        print("Clicked on TimelineView background, cleared selection")
                    }
                }
            }
        }
        .environmentObject(menuCoordinator)
    }
    
    // MARK: - Zoom Controls
    
    // Zoom in one level
    private func zoomIn() {
        // Store the current beat position
        let currentBeat = projectViewModel.currentBeat
        
        // Decrease zoom level (lower number means more zoomed in)
        if timelineState.zoomLevel > 0 {
            // Use DispatchQueue.main.async to prevent "modifying state during view update" errors
            DispatchQueue.main.async {
                self.timelineState.zoomLevel -= 1
            }
        }
        
        // Ensure the playhead stays at the correct position
        if !projectViewModel.isPlaying {
            projectViewModel.seekToBeat(currentBeat)
        }
    }
    
    // Zoom out one level
    private func zoomOut() {
        // Store the current beat position
        let currentBeat = projectViewModel.currentBeat
        
        // Increase zoom level (higher number means more zoomed out)
        if timelineState.zoomLevel < 6 {
            // Use DispatchQueue.main.async to prevent "modifying state during view update" errors
            DispatchQueue.main.async {
                self.timelineState.zoomLevel += 1
            }
        }
        
        // Ensure the playhead stays at the correct position
        if !projectViewModel.isPlaying {
            projectViewModel.seekToBeat(currentBeat)
        }
    }
    
    // Reset zoom to default level (3)
    private func resetZoom() {
        // Store the current beat position
        let currentBeat = projectViewModel.currentBeat
        
        // Reset to default zoom level
        // Use DispatchQueue.main.async to prevent "modifying state during view update" errors
        DispatchQueue.main.async {
            self.timelineState.zoomLevel = 3
        }
        
        // Ensure the playhead stays at the correct position
        if !projectViewModel.isPlaying {
            projectViewModel.seekToBeat(currentBeat)
        }
    }
    
    // Calculate the width of the timeline content based on zoom level
    private func calculateContentWidth(geometry: GeometryProxy) -> CGFloat {
        let baseWidth = max(
            timelineState.calculateContentWidth(
                viewWidth: geometry.size.width - controlsWidth,
                timeSignatureBeats: projectViewModel.timeSignatureBeats,
                tracks: projectViewModel.tracks
            ),
            geometry.size.width - controlsWidth
        )
        
        // Ensure the width is at least the visible area width
        return max(baseWidth, geometry.size.width - controlsWidth)
    }
    
    // Show a menu to add different track types
    private func showAddTrackMenu() {
        let menu = NSMenu(title: "Add Track")
        
        // Use our coordinator for the selectors
        menu.addItem(withTitle: "Audio Track", action: #selector(MenuCoordinator.addAudioTrack), keyEquivalent: "t")
            .target = menuCoordinator
        
        menu.addItem(withTitle: "MIDI Track", action: #selector(MenuCoordinator.addMidiTrack), keyEquivalent: "T")
            .target = menuCoordinator
        
        if let event = NSApplication.shared.currentEvent,
           let contentView = NSApp.mainWindow?.contentView {
            NSMenu.popUpContextMenu(menu, with: event, for: contentView)
        }
    }
    
    // Show a context menu for the timeline
    func showTimelineContextMenu(at location: CGPoint) {
        let menu = NSMenu(title: "Timeline")
        
        // Check if there's an active selection on a track
        if timelineState.selectionActive,
           let trackId = projectViewModel.selectedTrackId,
           let trackIndex = projectViewModel.tracks.firstIndex(where: { $0.id == trackId }) {
            
            // Get the track (non-optional since we have a valid index)
            let track = projectViewModel.tracks[trackIndex]
            
            // Handle MIDI tracks
            if track.type == .midi {
                // Get the selection range
                let (selStart, selEnd) = timelineState.normalizedSelectionRange
                
                // Check if the selection matches a MIDI clip exactly using the MidiViewModel
                let isClipSelected = projectViewModel.midiViewModel.isMidiClipSelected(trackId: trackId)
                
                if isClipSelected {
                    // This is a selected MIDI clip - show clip-specific options
                    print("Found selected MIDI clip")
                    
                    menu.addItem(withTitle: "Rename Clip", action: #selector(MenuCoordinator.renameSelectedClip), keyEquivalent: "r")
                        .target = menuCoordinator
                    
                    // Add Copy option for MIDI clips
                    let copyItem = menu.addItem(withTitle: "Copy Clip", action: #selector(MenuCoordinator.copySelectedClip), keyEquivalent: "c")
                    copyItem.target = menuCoordinator
                    copyItem.keyEquivalentModifierMask = .command
                    
                    // Add Duplicate option for MIDI clips
                    let duplicateItem = menu.addItem(withTitle: "Duplicate Clip", action: #selector(MenuCoordinator.duplicateSelectedClip), keyEquivalent: "d")
                    duplicateItem.target = menuCoordinator
                    duplicateItem.keyEquivalentModifierMask = .command
                    
                    menu.addItem(withTitle: "Delete Clip", action: #selector(MenuCoordinator.deleteSelectedClip), keyEquivalent: "\u{8}") // Backspace key
                        .target = menuCoordinator
                    
                    menu.addItem(withTitle: "Edit Notes", action: #selector(MenuCoordinator.editClipNotes), keyEquivalent: "e")
                        .target = menuCoordinator
                } else {
                    // Check if the selection overlaps with any clips
                    let overlappingClips = track.midiClips.filter { clip in
                        selStart < clip.endBeat && selEnd > clip.startBeat
                    }
                    
                    if !overlappingClips.isEmpty {
                        // Selection overlaps with clips but doesn't match exactly - show option to copy partial clip
                        let copyItem = menu.addItem(withTitle: "Copy Partial Clip", action: #selector(MenuCoordinator.copySelectedClip), keyEquivalent: "c")
                        copyItem.target = menuCoordinator
                        copyItem.keyEquivalentModifierMask = .command
                        
                        // Selection overlaps with clips but doesn't match exactly - show option to trim
                        menu.addItem(withTitle: "Trim Clip", action: #selector(MenuCoordinator.deleteSelectedClip), keyEquivalent: "\u{8}") // Backspace key
                            .target = menuCoordinator
                    } else {
                        // This is a regular selection - show option to create a new clip
                        print("No MIDI clip found at selection")
                        
                        menu.addItem(withTitle: "Create MIDI Clip", action: #selector(MenuCoordinator.createMidiClip), keyEquivalent: "n")
                            .target = menuCoordinator
                    }
                }
                
                // Add Paste option for MIDI tracks regardless of selection
                let pasteItem = menu.addItem(withTitle: "Paste Clip", action: #selector(MenuCoordinator.pasteClip), keyEquivalent: "v")
                pasteItem.target = menuCoordinator
                pasteItem.keyEquivalentModifierMask = .command
                
                menu.addItem(NSMenuItem.separator())
            }
            // Handle Audio tracks
            else if track.type == .audio {
                // Get the selection range
                let (selStart, selEnd) = timelineState.normalizedSelectionRange
                
                // Check if the selection matches an audio clip exactly using the AudioViewModel
                let isClipSelected = projectViewModel.audioViewModel.isAudioClipSelected(trackId: trackId)
                
                if isClipSelected {
                    // This is a selected audio clip - show clip-specific options
                    print("Found selected audio clip")
                    
                    menu.addItem(withTitle: "Rename Clip", action: #selector(MenuCoordinator.renameSelectedClip), keyEquivalent: "r")
                        .target = menuCoordinator
                    
                    // Add Copy option for audio clips
                    let copyItem = menu.addItem(withTitle: "Copy Clip", action: #selector(MenuCoordinator.copySelectedClip), keyEquivalent: "c")
                    copyItem.target = menuCoordinator
                    copyItem.keyEquivalentModifierMask = .command
                    
                    // Add Duplicate option for audio clips
                    let duplicateItem = menu.addItem(withTitle: "Duplicate Clip", action: #selector(MenuCoordinator.duplicateSelectedClip), keyEquivalent: "d")
                    duplicateItem.target = menuCoordinator
                    duplicateItem.keyEquivalentModifierMask = .command
                    
                    menu.addItem(withTitle: "Delete Clip", action: #selector(MenuCoordinator.deleteSelectedClip), keyEquivalent: "\u{8}") // Backspace key
                        .target = menuCoordinator
                    
                    menu.addItem(withTitle: "Edit Audio", action: #selector(MenuCoordinator.editAudioClip), keyEquivalent: "e")
                        .target = menuCoordinator
                } else {
                    // Check if the selection overlaps with any clips
                    let overlappingClips = track.audioClips.filter { clip in
                        selStart < clip.endBeat && selEnd > clip.startPositionInBeats
                    }
                    
                    if !overlappingClips.isEmpty {
                        // Selection overlaps with clips but doesn't match exactly - show option to copy partial clip
                        let copyItem = menu.addItem(withTitle: "Copy Partial Clip", action: #selector(MenuCoordinator.copySelectedClip), keyEquivalent: "c")
                        copyItem.target = menuCoordinator
                        copyItem.keyEquivalentModifierMask = .command
                        
                        // Selection overlaps with clips but doesn't match exactly - show option to trim
                        menu.addItem(withTitle: "Trim Clip", action: #selector(MenuCoordinator.deleteSelectedClip), keyEquivalent: "\u{8}") // Backspace key
                            .target = menuCoordinator
                    } else {
                        // This is a regular selection - show option to create a new clip
                        print("No audio clip found at selection")
                        
                        menu.addItem(withTitle: "Create Audio Clip", action: #selector(MenuCoordinator.createAudioClip), keyEquivalent: "n")
                            .target = menuCoordinator
                    }
                }
                
                // Add Paste option for audio tracks regardless of selection
                let pasteItem = menu.addItem(withTitle: "Paste Clip", action: #selector(MenuCoordinator.pasteClip), keyEquivalent: "v")
                pasteItem.target = menuCoordinator
                pasteItem.keyEquivalentModifierMask = .command
                
                menu.addItem(NSMenuItem.separator())
            }
        }
        
        // Add track options
        let audioTrackItem = menu.addItem(withTitle: "Add Audio Track", action: #selector(MenuCoordinator.addAudioTrack), keyEquivalent: "a")
        audioTrackItem.target = menuCoordinator
        audioTrackItem.keyEquivalentModifierMask = [.command, .shift]
        
        let midiTrackItem = menu.addItem(withTitle: "Add MIDI Track", action: #selector(MenuCoordinator.addMidiTrack), keyEquivalent: "m")
        midiTrackItem.target = menuCoordinator
        midiTrackItem.keyEquivalentModifierMask = [.command, .shift]
        
        if let event = NSApplication.shared.currentEvent,
           let contentView = NSApp.mainWindow?.contentView {
            NSMenu.popUpContextMenu(menu, with: event, for: contentView)
        }
    }
}

#Preview {
    TimelineView(projectViewModel: ProjectViewModel())
        .environmentObject(ThemeManager())
}
