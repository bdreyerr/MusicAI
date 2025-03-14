import SwiftUI
import Combine
import AppKit

/// Main timeline view for the DAW application
struct TimelineView: View {
    @StateObject private var timelineState = TimelineState()
    @State private var startDragY: CGFloat = 0
    @State private var isDragging: Bool = false
    @StateObject private var menuCoordinator = MenuCoordinator()
    @ObservedObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    // Constants
    let rulerHeight: CGFloat = 25
    let trackHeight: CGFloat = 70
    let controlsWidth: CGFloat = 200 // Must match TrackView.controlsWidth
    
    // Initialize with project view model
    init(projectViewModel: ProjectViewModel) {
        self.projectViewModel = projectViewModel
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Single ScrollView for both ruler and tracks content
                HStack(spacing: 0) {
                    // Fixed column for track controls
                    VStack(spacing: 0) {
                        // Fixed space for ruler
                        Rectangle()
                            .fill(themeManager.tertiaryBackgroundColor)
                            .frame(width: controlsWidth, height: rulerHeight)
                        
                        // Track controls with zero spacing
                        ForEach(projectViewModel.tracks) { track in
                            TrackControlsView(
                                track: track,
                                projectViewModel: projectViewModel
                            )
                            .environmentObject(themeManager)
                            .frame(width: controlsWidth, height: trackHeight)
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
                    
                    // Scrollable content area (ruler + tracks)
                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(spacing: 0) {
                            // Ruler
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
                                            
                                            // Set initial cursor to magnifying glass
                                            NSCursor.openHand.set()
                                        }
                                        
                                        // Calculate zoom change based on vertical drag
                                        let dragDelta = value.location.y - startDragY
                                        let zoomDelta = dragDelta / 200.0
                                        
                                        // REVERSED: Dragging up decreases zoom (zooms out), dragging down increases zoom (zooms in)
                                        let newZoom = timelineState.zoomLevel + zoomDelta
                                        
                                        // Clamp zoom to reasonable values (matching old implementation)
                                        timelineState.zoomLevel = max(0.146, min(2.0, newZoom))
                                        
                                        // Update cursor based on drag direction
                                        if dragDelta < 0 {
                                            // Moving up - zooming out
                                            NSCursor.closedHand.set()
                                        } else {
                                            // Moving down - zooming in
                                            NSCursor.closedHand.set()
                                        }
                                        
                                        // Update startDragY for smooth zooming
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
                            
                            // Tracks content
                            ZStack(alignment: .topLeading) {
                                // Track content with zero spacing
                                VStack(spacing: 0) {
                                    // Track rows with explicit zero spacing
                                    ForEach(projectViewModel.tracks) { track in
                                        TrackView(
                                            track: track,
                                            state: timelineState,
                                            projectViewModel: projectViewModel,
                                            width: calculateContentWidth(geometry: geometry)
                                        )
                                        .environmentObject(themeManager)
                                        .frame(height: trackHeight)
                                    }
                                    
                                    // Empty space for the add track button area
                                    Rectangle()
                                        .fill(Color.clear)
                                        .frame(height: 40)
                                        .padding(.top, 4)
                                    
                                    Spacer(minLength: 100)
                                }
                                
                                // Playhead indicator that spans all tracks
                                PlayheadIndicator(
                                    currentBeat: projectViewModel.currentBeat,
                                    state: timelineState
                                )
                                .environmentObject(themeManager)
                            }
                            .frame(height: geometry.size.height - rulerHeight)
                        }
                        .frame(width: calculateContentWidth(geometry: geometry))
                    }
                }
                .frame(height: geometry.size.height)
            }
            .background(themeManager.backgroundColor)
            .onAppear {
                // Connect the coordinator to our view model
                menuCoordinator.projectViewModel = projectViewModel
            }
        }
    }
    
    // Calculate the width of the timeline content based on zoom level
    private func calculateContentWidth(geometry: GeometryProxy) -> CGFloat {
        return timelineState.calculateContentWidth(
            viewWidth: geometry.size.width - controlsWidth,
            timeSignatureBeats: projectViewModel.timeSignatureBeats
        )
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
}

#Preview {
    TimelineView(projectViewModel: ProjectViewModel())
        .environmentObject(ThemeManager())
}
