import SwiftUI

// MARK: - Track Controls Content

struct TrackControlsContent: View {
    let track: Track
    @ObservedObject var projectViewModel: ProjectViewModel
    @ObservedObject var trackViewModel: TrackViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var menuCoordinator: MenuCoordinator
    
    var body: some View {
        VStack(spacing: 2) {
            // Track icon and name
            TrackHeaderView(
                track: track, 
                trackViewModel: trackViewModel
            )
            .environmentObject(themeManager)
            
            // Only show additional controls when track is not collapsed
            if !trackViewModel.isCollapsed {
                // Controls row
                TrackButtonsView(
                    track: track, 
                    trackViewModel: trackViewModel,
                    onDelete: { trackViewModel.showingDeleteConfirmation = true }
                )
                .environmentObject(themeManager)
                .alert(isPresented: $trackViewModel.showingDeleteConfirmation) {
                    Alert(
                        title: Text("Delete Track"),
                        message: Text("Are you sure you want to delete '\(trackViewModel.trackName)'? This cannot be undone."),
                        primaryButton: .destructive(Text("Delete")) {
                            trackViewModel.deleteTrack()
                        },
                        secondaryButton: .cancel()
                    )
                }
                
                // Volume slider section - keep this in its own row
                VolumeSliderView(trackViewModel: trackViewModel)
                    .environmentObject(themeManager)
            }
        }
        .frame(maxWidth: .infinity)
    }
} 