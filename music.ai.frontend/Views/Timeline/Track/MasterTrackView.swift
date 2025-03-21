import SwiftUI
import Foundation

/// View for the master track in the timeline
struct MasterTrackView: View {
    let track: Track
    @ObservedObject var state: TimelineStateViewModel
    @ObservedObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var menuCoordinator: MenuCoordinator
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
        // Mute option
        Button(track.isMuted ? "Unmute Master" : "Mute Master") {
            toggleMute()
        }
        
        Divider()
        
        // Add effect option
        Button("Add Effect") {
            addEffect()
        }
        
        if !track.effects.isEmpty {
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
    
    // MARK: - Helper Methods
    
    private func toggleMute() {
        var updatedTrack = projectViewModel.masterTrack
        updatedTrack.isMuted = !updatedTrack.isMuted
        projectViewModel.masterTrack = updatedTrack
    }
    
    private func addEffect() {
        // Select the master track
        projectViewModel.selectTrack(id: track.id)
        
        // Add a compressor effect
        var updatedTrack = projectViewModel.masterTrack
        let effect = Effect(type: .compressor, name: "Compressor")
        updatedTrack.addEffect(effect)
        projectViewModel.masterTrack = updatedTrack
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
