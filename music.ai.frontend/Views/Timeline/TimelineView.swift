import SwiftUI
import Combine
import AppKit

// Preference key to track scroll position
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGPoint = .zero
    
    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {
        value = nextValue()
    }
}

// View modifier to track scroll position
struct ScrollViewOffsetTracker: ViewModifier {
    let coordinatorID: String
    @Binding var offset: CGPoint
    
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: CGPoint(
                                x: geo.frame(in: .named(coordinatorID)).minX * -1,
                                y: geo.frame(in: .named(coordinatorID)).minY * -1
                            )
                        )
                }
            )
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                offset = value
            }
    }
}

// Coordinator to synchronize horizontal scrolling
class ScrollSyncCoordinator: ObservableObject {
    @Published var tracksOffset: CGPoint = .zero
    let id = "scroll-sync-coordinator"
}

/// Main timeline view for the DAW application
struct TimelineView: View {
    @StateObject private var timelineState = TimelineState()
    @State private var startDragY: CGFloat = 0
    @State private var isDragging: Bool = false
    @StateObject private var menuCoordinator = MenuCoordinator()
    @StateObject private var scrollSyncCoordinator = ScrollSyncCoordinator()
    @ObservedObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    // Constants
    let rulerHeight: CGFloat = 25
    let defaultTrackHeight: CGFloat = 70 // Default height for new tracks
    let controlsWidth: CGFloat = 200 // Must match TrackView.controlsWidth
    
    // Initialize with project view model
    init(projectViewModel: ProjectViewModel) {
        self.projectViewModel = projectViewModel
        // We'll connect the timeline state in onAppear instead of here
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 0) {
                    // Use a ScrollViewReader to coordinate scrolling
                    ScrollViewReader { scrollProxy in
                        // Single ScrollView for vertical scrolling
                        ScrollView(.vertical, showsIndicators: true) {
                            // Use a LazyVStack to ensure views are only created when needed
                            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                                // Header section with ruler
                                Section(header: 
                                    // Header with ruler that stays pinned
                                    HStack(spacing: 0) {
                                        // Ruler label area
                                        Rectangle()
                                            .fill(themeManager.tertiaryBackgroundColor)
                                            .frame(width: controlsWidth, height: rulerHeight)
                                        
                                        // Non-scrollable ruler that syncs with tracks
                                        ZStack(alignment: .topLeading) {
                                            TimelineRuler(
                                                state: timelineState,
                                                projectViewModel: projectViewModel,
                                                width: calculateContentWidth(geometry: geometry),
                                                height: rulerHeight
                                            )
                                            .environmentObject(themeManager)
                                            .gesture(
                                                DragGesture(minimumDistance: 0)
                                                    .onChanged { value in
                                                        if !isDragging {
                                                            startDragY = value.location.y
                                                            isDragging = true
                                                            NSCursor.openHand.set()
                                                        }
                                                        
                                                        let dragDelta = value.location.y - startDragY
                                                        let zoomDelta = dragDelta / 200.0
                                                        let newZoom = timelineState.zoomLevel + zoomDelta
                                                        
                                                        // Store the current beat position before zooming
                                                        let currentBeat = projectViewModel.currentBeat
                                                        
                                                        // Update the zoom level
                                                        timelineState.zoomLevel = max(0.146, min(2.0, newZoom))
                                                        
                                                        // Ensure the playhead stays at the correct beat position
                                                        // This is redundant but ensures the position is updated
                                                        projectViewModel.seekToBeat(currentBeat)
                                                        
                                                        if dragDelta < 0 {
                                                            NSCursor.closedHand.set()
                                                        } else {
                                                            NSCursor.closedHand.set()
                                                        }
                                                        
                                                        startDragY = value.location.y
                                                    }
                                                    .onEnded { _ in
                                                        isDragging = false
                                                        NSCursor.arrow.set()
                                                    }
                                            )
                                            .onHover { hovering in
                                                if hovering {
                                                    NSCursor.openHand.set()
                                                } else {
                                                    NSCursor.arrow.set()
                                                }
                                            }
                                            
                                            // Add the ruler selection indicator
                                            TimelineRulerSelectionIndicator(
                                                state: timelineState,
                                                projectViewModel: projectViewModel,
                                                height: rulerHeight
                                            )
                                            .environmentObject(themeManager)
                                        }
                                        // Offset the ruler based on tracks scrolling
                                        .offset(x: -scrollSyncCoordinator.tracksOffset.x)
                                        // Clip the ruler to the visible area
                                        .frame(width: geometry.size.width - controlsWidth, height: rulerHeight, alignment: .leading)
                                        .clipped()
                                    }
                                    .background(themeManager.tertiaryBackgroundColor)
                                    .frame(height: rulerHeight)
                                ) {
                                    HStack(spacing: 0) {
                                        // Left side: Track controls column
                                        VStack(spacing: 0) {
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
                                        
                                        // Right side: Single horizontal scroll view for all tracks
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            VStack(spacing: 0) {
                                                // All track content
                                                ForEach(projectViewModel.tracks) { track in
                                                    ZStack(alignment: .topLeading) {
                                                        TrackView(
                                                            track: track,
                                                            state: timelineState,
                                                            projectViewModel: projectViewModel,
                                                            width: calculateContentWidth(geometry: geometry)
                                                        )
                                                        .environmentObject(themeManager)
                                                        
                                                        // Playhead indicator for this track
                                                        PlayheadIndicator(
                                                            currentBeat: projectViewModel.currentBeat,
                                                            state: timelineState,
                                                            track: track,
                                                            projectViewModel: projectViewModel
                                                        )
                                                        .environmentObject(themeManager)
                                                        .frame(height: track.height)
                                                    }
                                                }
                                                
                                                // Empty space for the add track button area
                                                Rectangle()
                                                    .fill(Color.clear)
                                                    .frame(height: 40)
                                                    .padding(.top, 4)
                                                    // Clear selection when clicking on empty space
                                                    .onTapGesture {
                                                        timelineState.clearSelection()
                                                    }
                                                
                                                Spacer()
                                            }
                                            .frame(width: calculateContentWidth(geometry: geometry))
                                            .background(
                                                GeometryReader { geo in
                                                    Color.clear
                                                        .preference(
                                                            key: ScrollOffsetPreferenceKey.self,
                                                            value: CGPoint(
                                                                x: geo.frame(in: .named(scrollSyncCoordinator.id)).minX * -1,
                                                                y: geo.frame(in: .named(scrollSyncCoordinator.id)).minY * -1
                                                            )
                                                        )
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
                                                                // Check if this is a right-click (secondary click)
                                                                if let event = NSApp.currentEvent, event.type == .rightMouseUp {
                                                                    showTimelineContextMenu(at: value.location)
                                                                }
                                                            }
                                                    )
                                            )
                                        }
                                        .coordinateSpace(name: scrollSyncCoordinator.id)
                                        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                                            scrollSyncCoordinator.tracksOffset = value
                                        }
                                        .frame(width: geometry.size.width - controlsWidth)
                                    }
                                    
                                    // Extra space at the bottom
                                    Rectangle()
                                        .fill(Color.clear)
                                        .frame(height: 100)
                                        .id("bottom-space")
                                }
                            }
                        }
                    }
//                    .onChange(of: projectViewModel.tracks.count) { _ in
//                        // When tracks are added or removed, scroll to the last track
//                        withAnimation {
//                            scrollProxy.scrollTo("bottom-space", anchor: .bottom)
//                        }
//                    }
                }
                .background(themeManager.backgroundColor)
                .onAppear {
                    // Connect the coordinator to our view model
                    menuCoordinator.projectViewModel = projectViewModel
                    // Set the default track height
                    menuCoordinator.defaultTrackHeight = defaultTrackHeight
                    // Connect the timeline state to the project view model
                    projectViewModel.timelineState = timelineState
                }
                // Respond to zoom level changes
                .onChange(of: timelineState.zoomLevel) { newZoomLevel in
                    // Ensure the playhead stays at the correct beat position after zoom changes
                    let currentBeat = projectViewModel.currentBeat
                    // This is redundant but ensures the position is updated
                    projectViewModel.seekToBeat(currentBeat)
                }
                // Clear selection when clicking on the background
                .contentShape(Rectangle())
                .onTapGesture {
                    timelineState.clearSelection()
                    print("Clicked on TimelineView background, cleared selection")
                }
                
                // Position indicator for scrubbing - we don't need it since we have the beeat position in controls bar
//                ScrubPositionIndicator(
//                    projectViewModel: projectViewModel,
//                    state: timelineState
//                )
//                .padding(.top, 40)
//                .padding(.trailing, 20)
            }
        }
    }
    
    // Calculate the width of the timeline content based on zoom level
    private func calculateContentWidth(geometry: GeometryProxy) -> CGFloat {
        let baseWidth = max(
            timelineState.calculateContentWidth(
                viewWidth: geometry.size.width - controlsWidth,
                timeSignatureBeats: projectViewModel.timeSignatureBeats
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
        menu.addItem(withTitle: "Audio Track", action: #selector(MenuCoordinator.addAudioTrack), keyEquivalent: "")
            .target = menuCoordinator
        
        menu.addItem(withTitle: "MIDI Track", action: #selector(MenuCoordinator.addMidiTrack), keyEquivalent: "")
            .target = menuCoordinator
        
        if let event = NSApplication.shared.currentEvent,
           let contentView = NSApp.mainWindow?.contentView {
            NSMenu.popUpContextMenu(menu, with: event, for: contentView)
        }
    }
    
    // Show a context menu for the timeline
    func showTimelineContextMenu(at location: CGPoint) {
        let menu = NSMenu(title: "Timeline")
        
        // Check if there's an active selection on a MIDI track
        if timelineState.selectionActive,
           let trackId = timelineState.selectionTrackId,
           let trackIndex = projectViewModel.tracks.firstIndex(where: { $0.id == trackId }) {
            
            // Get the track (non-optional since we have a valid index)
            let track = projectViewModel.tracks[trackIndex]
            
            // Only proceed if this is a MIDI track
            if track.type == .midi {
                // Get the selection range
                let (selStart, selEnd) = timelineState.normalizedSelectionRange
                
                // Debug info
//                print("Selection: \(selStart) to \(selEnd)")
//                if !track.midiClips.isEmpty {
//                    print("Available clips:")
//                    for clip in track.midiClips {
//                        print("  - \(clip.name): \(clip.startBeat) to \(clip.endBeat)")
//                    }
//                }
                
                // Check if the selection matches a MIDI clip exactly
                let selectedClip = track.midiClips.first(where: { clip in
                    abs(clip.startBeat - selStart) < 0.001 && abs(clip.endBeat - selEnd) < 0.001
                })
                
                if let selectedClip = selectedClip {
                    // This is a selected MIDI clip - show clip-specific options
                    print("Found selected clip: \(selectedClip.name)")
                    
                    menu.addItem(withTitle: "Rename Clip", action: #selector(MenuCoordinator.renameSelectedClip), keyEquivalent: "")
                        .target = menuCoordinator
                    
                    menu.addItem(withTitle: "Delete Clip", action: #selector(MenuCoordinator.deleteSelectedClip), keyEquivalent: "")
                        .target = menuCoordinator
                    
                    menu.addItem(withTitle: "Edit Notes", action: #selector(MenuCoordinator.editClipNotes), keyEquivalent: "")
                        .target = menuCoordinator
                } else {
                    // This is a regular selection - show option to create a new clip
                    print("No clip found at selection")
                    
                    menu.addItem(withTitle: "Create MIDI Clip", action: #selector(MenuCoordinator.createMidiClip), keyEquivalent: "")
                        .target = menuCoordinator
                }
                
                menu.addItem(NSMenuItem.separator())
            }
        }
        
        // Add track options
        menu.addItem(withTitle: "Add Audio Track", action: #selector(MenuCoordinator.addAudioTrack), keyEquivalent: "")
            .target = menuCoordinator
        
        menu.addItem(withTitle: "Add MIDI Track", action: #selector(MenuCoordinator.addMidiTrack), keyEquivalent: "")
            .target = menuCoordinator
        
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
