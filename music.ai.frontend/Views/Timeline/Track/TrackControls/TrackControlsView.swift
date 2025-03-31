import SwiftUI
import AppKit

/// View for the controls section of a track in the timeline
struct TrackControlsView: View {
    let track: Track
    @ObservedObject var projectViewModel: ProjectViewModel
    @ObservedObject var trackViewModel: TrackViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var menuCoordinator: MenuCoordinator
    
    // Initialize with track's current state
    init(track: Track, projectViewModel: ProjectViewModel) {
        self.track = track
        self.projectViewModel = projectViewModel
        
        // Get the track view model from the manager
        self._trackViewModel = ObservedObject(wrappedValue: projectViewModel.trackViewModelManager.viewModel(for: track))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main track controls
            TrackControlsContent(
                track: track,
                projectViewModel: projectViewModel,
                trackViewModel: trackViewModel
            )
            .environmentObject(themeManager)
            .environmentObject(menuCoordinator)
        }
        .frame(height: trackViewModel.isCollapsed ? 30 : 70)
        .frame(minHeight: trackViewModel.isCollapsed ? 30 : 40)
        .background(Color.clear) // Removed background color
        .contentShape(Rectangle())
        .onTapGesture(count: 1, perform: {
            // Make track controls selectable with a single tap
            projectViewModel.selectTrack(id: track.id)
        }) 
        .simultaneousGesture(TapGesture(count: 2).onEnded {
            trackViewModel.toggleCollapsed()
        })
        .contextMenu {
            trackControlsContextMenu
        }
        // Add a selection highlight for the entire control area
        .overlay(
            ZStack {
                // Regular border for all tracks
                Rectangle()
                    .stroke(themeManager.secondaryBorderColor, lineWidth: 0.5)
                    .allowsHitTesting(false)
                
                // Selection highlight for the entire control area
                if projectViewModel.isTrackSelected(track) {
                    Rectangle()
                        .fill(trackViewModel.effectiveColor.opacity(0.1)) // Light opacity for selection
                        .allowsHitTesting(false)
                    
                    // Selection border
                    Rectangle()
                        .stroke(trackViewModel.effectiveColor.opacity(0.6), lineWidth: 0.5)
                        .allowsHitTesting(false)
                }
            }
        )
        .opacity(trackViewModel.isEnabled ? 1.0 : 0.7) // Dim the controls if track is disabled
    }
    
    // MARK: - Context Menu
    
    @ViewBuilder
    private var trackControlsContextMenu: some View {
        // Enable/Disable option
        Button(trackViewModel.isEnabled ? "Disable Track" : "Enable Track") {
            trackViewModel.toggleEnabled()
        }
        
        // Mute option
        Button(trackViewModel.isMuted ? "Unmute Track" : "Mute Track") {
            trackViewModel.toggleMute()
        }
        
        // Solo option
        Button(trackViewModel.isSolo ? "Unsolo Track" : "Solo Track (Exclusive)") {
            trackViewModel.toggleSolo()
        }
        
        // Collapse/Expand option
        Button(trackViewModel.isCollapsed ? "Expand Track" : "Collapse Track") {
            trackViewModel.toggleCollapsed()
        }
        
        Divider()
        
        // Rename option
        Button("Rename Track") {
            showRenameDialog()
        }
        
        // Change color option
        Button("Change Color") {
            trackViewModel.showingColorPicker = true
        }
        
        // Delete option
        Button("Delete Track", role: .destructive) {
            trackViewModel.showingDeleteConfirmation = true
        }
    }
    
    // Show rename dialog
    private func showRenameDialog() {
        // Show a popup to get the new name
        let alert = NSAlert()
        alert.messageText = "Rename Track"
        alert.informativeText = "Enter a new name for the track:"
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        textField.stringValue = trackViewModel.trackName
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
