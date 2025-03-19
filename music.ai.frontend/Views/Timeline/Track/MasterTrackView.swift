import SwiftUI
import Foundation

/// View for the master track in the timeline
struct MasterTrackView: View {
    let track: Track
    @ObservedObject var state: TimelineStateViewModel
    @ObservedObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var themeManager: ThemeManager
    let width: CGFloat
    
    var body: some View {
        // Master track content section
        ZStack(alignment: .topLeading) {
            // Track background with borders
            Rectangle()
                .fill(themeManager.backgroundColor.opacity(0.6))
                .overlay(
                    Rectangle()
                        .stroke(themeManager.secondaryBorderColor, lineWidth: 0.5)
                )
                .allowsHitTesting(false)
            
            // Selection overlay
            TimelineSelectionOverlay(
                state: state,
                projectViewModel: projectViewModel,
                track: track
            )
            .environmentObject(themeManager)
            .zIndex(5)
            .id("master-selection-overlay-\(track.id)-\(state.selectionActive ? "active" : "inactive")-\(state.selectionStartBeat)-\(state.selectionEndBeat)")
            
            // Timeline selector for handling clicks and drags
            TimelineSelector(
                projectViewModel: projectViewModel,
                state: state,
                track: track
            )
            .contentShape(Rectangle())
            .zIndex(20)
        }
        .frame(width: width, height: 70)
        .background(Color.clear)
        .contextMenu { masterTrackContextMenu }
        // Apply highlight if this track is selected
        .overlay(
            ZStack {
                if projectViewModel.isTrackSelected(track) {
                    Rectangle()
                        .fill(themeManager.accentColor.opacity(0.1))
                        .allowsHitTesting(false)
                    
                    Rectangle()
                        .stroke(themeManager.accentColor, lineWidth: 2)
                        .allowsHitTesting(false)
                }
            }
        )
        .onTapGesture {
            projectViewModel.selectTrack(id: track.id)
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var masterTrackContextMenu: some View {
        // Only show effects-related options for master track
        Button("Add Effect") {
            // Select the master track first
            projectViewModel.selectTrack(id: track.id)
            
            // Add a compressor effect directly
            if let trackIndex = projectViewModel.tracks.firstIndex(where: { $0.id == track.id }) {
                var updatedTrack = projectViewModel.tracks[trackIndex]
                let effect = Effect(type: .compressor, name: "Compressor")
                updatedTrack.addEffect(effect)
                
                // Update the track with the new effect
                projectViewModel.updateTrack(at: trackIndex, with: updatedTrack)
            }
        }
        
        if track.effects.count > 0 {
            Menu("Effects (\(track.effects.count))") {
                ForEach(track.effects) { effect in
                    Button("\(effect.name)") {
                        // Future: Open effect editor
                        projectViewModel.selectTrack(id: track.id)
                    }
                }
                
                Divider()
                
                Button("Manage Effects...") {
                    projectViewModel.selectTrack(id: track.id)
                    // TODO: Show effects panel when implemented
                }
            }
        }
    }
}

#Preview {
    // Create a sample master track for the preview
    let masterTrack = Track(name: "Master", type: .master)
    return MasterTrackView(
        track: masterTrack,
        state: TimelineStateViewModel(), 
        projectViewModel: ProjectViewModel(),
        width: 800
    )
    .environmentObject(ThemeManager())
} 