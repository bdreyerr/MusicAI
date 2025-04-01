import SwiftUI

/// Container view that holds the shared grid and all tracks layered on top
/// This improves performance by rendering the grid only once for all tracks
struct SharedTracksGridContainer: View {
    @ObservedObject var projectViewModel: ProjectViewModel
    @ObservedObject var state: TimelineStateViewModel
    @EnvironmentObject var themeManager: ThemeManager
    let width: CGFloat
    
    // Cache the track height calculation to avoid recalculating every render
    @State private var cachedTrackHeight: CGFloat = 0
    @State private var lastTrackCountForCache: Int = 0
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Shared grid rendered once for all tracks
            AppKitTimelineGridView(
                state: state,
                projectViewModel: projectViewModel,
                width: width,
                height: calculateTotalTracksHeight()
            )
            .environmentObject(themeManager)
//                .id("appkit-grid-\(state.zoomLevel)-\(state.totalBars)") // Make ID stable during scroll
            
            
            // Stack of track views without their individual grids
            VStack(spacing: 0) {
                ForEach(projectViewModel.tracks) { track in
                    TrackView(
                        track: track,
                        state: state,
                        projectViewModel: projectViewModel,
                        width: width
                    )
                    .environmentObject(themeManager)
                    .id("track-\(track.id)")
                }
                
                // Empty space for the add track button area
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 40)
                    .padding(.top, 4)
                    // Clear selection when clicking on empty space
                    .onTapGesture {
                        state.clearSelection()
                    }
            }
            .id("tracks-vstack-\(projectViewModel.tracks.map { $0.id.uuidString + (projectViewModel.trackViewModelManager.viewModel(for: $0).isCollapsed ? "-c" : "-e") }.joined())")
            .padding(.top, 0) // Ensure no top padding
            
            // Add "Add More Bars" button at the end of the timeline
            VStack {
                Spacer()
                
                // Add More Bars button
                Button(action: {
                    state.extendTimeline()
                }) {
                    VStack(spacing: 6) {
                        Image(systemName: "plus.rectangle")
                            .font(.system(size: 20))
                        Text("Add 16 Bars")
                            .font(.caption)
                    }
                    .padding(12)
                    .background(themeManager.secondaryBackgroundColor.opacity(0.8))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(themeManager.borderColor, lineWidth: 1)
                    )
                }
                .buttonStyle(BorderlessButtonStyle())
                .padding(8)
                .offset(x: calculateBarButtonOffset())
                
                Spacer()
            }
            .frame(height: calculateTotalTracksHeight())

            // Shared playhead on top (higher z-index)
            SharedPlayheadView(
                projectViewModel: projectViewModel,
                state: state,
                viewportWidth: width
            )
            .environmentObject(themeManager)
            .zIndex(1000) // Higher zIndex to ensure playhead is on top
        }
        .clipped() // Clip any content that exceeds bounds
        // Add magnification gesture for trackpad pinch zooming to the entire container
        .gesture(
            MagnificationGesture()
                .onChanged { scale in
                    // Handle the pinch zoom gesture using the state view model
                    // Use DispatchQueue.main.async to prevent state updates during view update
                    DispatchQueue.main.async {
                        state.handlePinchGesture(scale: scale)
                    }
                }
                .onEnded { _ in
                    // Reset with scale = 1.0 to signal end of gesture
                    // Use DispatchQueue.main.async to prevent state updates during view update
                    DispatchQueue.main.async {
                        state.handlePinchGesture(scale: 1.0)
                    }
                }
        )
        // Track content changes that should force a grid refresh
        .onChange(of: projectViewModel.tracks.count) { _, _ in
            // Reset cached height when track count changes
            // Use DispatchQueue.main.async to prevent state updates during view update
            DispatchQueue.main.async {
                self.lastTrackCountForCache = 0
            }
        }
    }
    
    // Calculate the total height of all tracks with caching for performance
    private func calculateTotalTracksHeight() -> CGFloat {
        // Use cached value if track count hasn't changed
        if projectViewModel.tracks.count == lastTrackCountForCache && cachedTrackHeight > 0 {
            return cachedTrackHeight
        }
        
        var totalHeight: CGFloat = 0
        
        // Sum up the height of all tracks, taking into account collapsed state
        for track in projectViewModel.tracks {
            // Get the track view model to check collapsed state
            let trackVM = projectViewModel.trackViewModelManager.viewModel(for: track)
            // Use collapsed height (30) or actual track height
            totalHeight += trackVM.isCollapsed ? 30 : track.height
        }
        
        // Add padding for the add track button area
        totalHeight += 44
        
        // Store the computed height for this render cycle
        let computedHeight = totalHeight
        
        // Capture values locally before the async block
        let trackCount = projectViewModel.tracks.count
        
        // Update cache asynchronously to avoid "modifying state during view update" warning
        DispatchQueue.main.async {
            // In a struct, 'self' is immutable and can't cause reference cycles
            self.cachedTrackHeight = computedHeight
            self.lastTrackCountForCache = trackCount
        }
        
        return computedHeight
    }
    
    // Calculate the offset for the "Add More Bars" button
    private func calculateBarButtonOffset() -> CGFloat {
        // Place button at the end of the content with some margin
        let pixelsPerBeat = state.effectivePixelsPerBeat
        let beatsPerBar = Double(projectViewModel.timeSignatureBeats)
        let barsToShow = state.totalBars
        
        // Calculate button position in pixels
        let contentEndPosition = CGFloat(barsToShow) * CGFloat(beatsPerBar) * CGFloat(pixelsPerBeat)
        
        // Add a small margin for better appearance
        return contentEndPosition + 16.0 - state.scrollOffset.x
    }
}

#Preview {
    SharedTracksGridContainer(
        projectViewModel: ProjectViewModel(),
        state: TimelineStateViewModel(),
        width: 800
    )
    .environmentObject(ThemeManager())
} 
