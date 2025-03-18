import SwiftUI

/// Container view that holds the shared grid and all tracks layered on top
/// This improves performance by rendering the grid only once for all tracks
struct SharedTracksGridContainer: View {
    @ObservedObject var projectViewModel: ProjectViewModel
    @ObservedObject var state: TimelineStateViewModel
    @EnvironmentObject var themeManager: ThemeManager
    let width: CGFloat
    
    // Performance optimization state
    @State private var lastGridRefreshTime = Date()
    @State private var shouldRenderDetailedGrid = true
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Update grid visibility based on scrolling performance optimization
            let shouldShowDetailedGrid = updateGridVisibility()
            
            // Shared grid rendered once for all tracks
            if shouldShowDetailedGrid {
                SharedGridView(
                    state: state,
                    projectViewModel: projectViewModel,
                    width: width,
                    height: calculateTotalTracksHeight()
                )
                .environmentObject(themeManager)
                .id("shared-grid-\(themeManager.themeChangeIdentifier)-\(state.zoomChanged)-\(state.contentSizeChangeId)")
                .transition(.opacity)
            }
            
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
                    .id("track-\(track.id)") // Add an ID to help with debugging
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
            
            // Add "Add More Bars" button at the end of the timeline
            VStack {
                // Position the button vertically centered
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
                state: state
            )
            .environmentObject(themeManager)
            .zIndex(1000) // Higher zIndex to ensure playhead is on top
        }
        // Add magnification gesture for trackpad pinch zooming to the entire container
        .gesture(
            MagnificationGesture()
                .onChanged { scale in
                    // Handle the pinch zoom gesture using the state view model
                    state.handlePinchGesture(scale: scale)
                }
                .onEnded { _ in
                    // Reset with scale = 1.0 to signal end of gesture
                    state.handlePinchGesture(scale: 1.0)
                }
        )
        .onChange(of: state.isScrolling) { _, newValue in
            // When scrolling stops, ensure detailed grid is visible again
            if !newValue {
                withAnimation(.easeIn(duration: 0.2)) {
                    shouldRenderDetailedGrid = true
                }
            }
        }
    }
    
    // Update the grid visibility based on scrolling performance
    private func updateGridVisibility() -> Bool {
        // Capture current state values to avoid repeated access
        let isCurrentlyScrolling = state.isScrolling
        let currentZoomLevel = state.zoomLevel
        let currentScrollingSpeed = state.scrollingSpeed
        let currentShouldRenderGrid = shouldRenderDetailedGrid
        
        // Always show grid when not scrolling
        if !isCurrentlyScrolling {
            return true
        }
        
        // For higher zoom levels (zoomed out), always show grid
        if currentZoomLevel >= 4 {
            return true
        }
        
        // Check scrolling speed to determine grid visibility
        if currentScrollingSpeed > 40 {
            // At extreme scroll speeds, hide detailed grid temporarily
            if currentShouldRenderGrid {
                // Schedule the animation to happen after the current view update is complete
                DispatchQueue.main.async {
                    withAnimation(.easeOut(duration: 0.1)) {
                        self.shouldRenderDetailedGrid = false
                    }
                }
            }
            return false
        } else if currentScrollingSpeed < 30 {
            // At moderate scroll speeds, show grid
            if !currentShouldRenderGrid {
                // Schedule the animation to happen after the current view update is complete
                DispatchQueue.main.async {
                    withAnimation(.easeIn(duration: 0.2)) {
                        self.shouldRenderDetailedGrid = true
                    }
                }
            }
            return true
        }
        
        // Otherwise, maintain current state
        return currentShouldRenderGrid
    }
    
    // Calculate the total height of all tracks
    private func calculateTotalTracksHeight() -> CGFloat {
        var totalHeight: CGFloat = 0
        
        // Sum up the height of all tracks
        for track in projectViewModel.tracks {
            totalHeight += track.height
        }
        
        // Add some padding for the add track button area
        totalHeight += 44
        
        return totalHeight
    }
    
    // Calculate the position for the "Add More Bars" button
    private func calculateBarButtonOffset() -> CGFloat {
        // Position the button at the end of the current timeline minus button width
        let pixelsPerBeat = state.effectivePixelsPerBeat
        let timeSignatureBeats = projectViewModel.timeSignatureBeats
        
        // Calculate the total timeline width in pixels
        let totalTimelineWidth = CGFloat(state.totalBars * timeSignatureBeats) * CGFloat(pixelsPerBeat)
        
        // Position the button just before the end of the timeline
        // Subtract approximately half the button width (70 pixels) to center it at the end
        return totalTimelineWidth - 70
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
