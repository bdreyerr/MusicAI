//
//  TimelineButtons.swift
//  music.ai.frontend
//
//  Created by Ben Dreyer on 3/20/25.
//

import SwiftUI

struct TimelineButtons: View {
    // View models needed for actions
    @ObservedObject var projectViewModel: ProjectViewModel
    @ObservedObject var timelineState: TimelineStateViewModel
    @State private var menuCoordinator = MenuCoordinator()
    
    // Initialize with required view models
    init(projectViewModel: ProjectViewModel, timelineState: TimelineStateViewModel) {
        self.projectViewModel = projectViewModel
        self.timelineState = timelineState
        
        // Connect the coordinator
        menuCoordinator.projectViewModel = projectViewModel
    }
    
    var body: some View {
        // Make sure these buttons are all invisible and take up no space on the view, they are only here for keyboard shortcut quick access
        Group {
            // Zoom in (cmd +)
            Button(action: {
                zoomIn()
            }) {
                EmptyView()
            }
            .keyboardShortcut("+", modifiers: [.command])
            
            // Zoom out (cmd -)
            Button(action: {
                zoomOut()
            }) {
                EmptyView()
            }
            .keyboardShortcut("-", modifiers: [.command])
            
            // Create audio track under selected track (cmd T)
            Button(action: {
                addTrack(type: .audio)
            }) {
                EmptyView()
            }
            .keyboardShortcut("t", modifiers: [.command])
            
            // Create midi track under selected track (cmd shift T)
            Button(action: {
                addTrack(type: .midi)
            }) {
                EmptyView()
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])
            
            // Create midi clip over selection in midi track (cmd shift m)
            Button(action: {
                createMidiClip()
            }) {
                EmptyView()
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])
            
            // Select track below currently selected track (down arrow)
            Button(action: {
                selectTrackBelow()
            }) {
                EmptyView()
            }
            .keyboardShortcut(.downArrow, modifiers: [])
            
            // Select track above currently selected track (up arrow)
            Button(action: {
                selectTrackAbove()
            }) {
                EmptyView()
            }
            .keyboardShortcut(.upArrow, modifiers: [])
            
            // Delete/trim selection (delete/backspace key)
            Button(action: {
                deleteSelection()
            }) {
                EmptyView()
            }
            .keyboardShortcut(.delete, modifiers: [])
            
            // // Also support backspace key for deletion
            // Button(action: {
            //     deleteSelection()
            // }) {
            //     EmptyView()
            // }
            // .keyboardShortcut(.init("\u{8}"), modifiers: [])
        }
        .frame(width: 0, height: 0)
        .opacity(0)
    }
    
    // MARK: - Actions
    
    // Zoom in
    private func zoomIn() {
        // Store the current beat position
        let currentBeat = projectViewModel.currentBeat
        
        // Decrease zoom level (lower number means more zoomed in)
        if timelineState.zoomLevel > 0 {
            DispatchQueue.main.async {
                self.timelineState.zoomLevel -= 1
            }
        }
        
        // Ensure the playhead stays at the correct position
        if !projectViewModel.isPlaying {
            projectViewModel.seekToBeat(currentBeat)
        }
    }
    
    // Zoom out
    private func zoomOut() {
        // Store the current beat position
        let currentBeat = projectViewModel.currentBeat
        
        // Increase zoom level (higher number means more zoomed out)
        if timelineState.zoomLevel < 6 {
            DispatchQueue.main.async {
                self.timelineState.zoomLevel += 1
            }
        }
        
        // Ensure the playhead stays at the correct position
        if !projectViewModel.isPlaying {
            projectViewModel.seekToBeat(currentBeat)
        }
    }
    
    // Add a new track (audio or MIDI)
    private func addTrack(type: TrackType) {
        // Create a name for the new track
        var name = type == .audio ? "Audio Track" : "MIDI Track"
        let height: CGFloat = 100 // Default height for new tracks
        let trackNumber = projectViewModel.tracks.count + 1
        name = "\(name) \(trackNumber)"
        
        // print("🔍 TimelineButtons: Adding new \(type) track with name: \(name)")
        // print("🔍 TimelineButtons: Current track count: \(projectViewModel.tracks.count)")
        // print("🔍 TimelineButtons: TimelineState selection active? \(timelineState.selectionActive)")
        // print("🔍 TimelineButtons: TimelineState selectionTrackId: \(timelineState.selectionTrackId?.uuidString ?? "nil")")
        // print("🔍 TimelineButtons: ProjectViewModel selectedTrackId: \(projectViewModel.selectedTrackId?.uuidString ?? "nil")")
        
        // If not, check if we have a selected track in the project view model
        if let trackId = projectViewModel.selectedTrackId,
                let selectedIndex = projectViewModel.tracks.firstIndex(where: { $0.id == trackId }) {
            // If a track is selected in the project view model, add the new track after it
            // print("✅ TimelineButtons: Found selected track in ProjectViewModel at index \(selectedIndex), adding new track after it")
            projectViewModel.addTrack(name: name, type: type, height: height, afterIndex: selectedIndex)
        }
        else {
            // If no track is selected anywhere, add to the end
            // print("⚠️ TimelineButtons: No track selected in either TimelineState or ProjectViewModel, adding to the end")
            projectViewModel.addTrack(name: name, type: type, height: height)
        }
        
        // Print tracks after adding to verify
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // print("📋 TimelineButtons: Track list after adding:")
            for (i, track) in self.projectViewModel.tracks.enumerated() {
                print("  \(i): \(track.name) (ID: \(track.id.uuidString.prefix(8))...)")
            }
        }
    }
    
    // Create a MIDI clip from selection
    private func createMidiClip() {
        // Use the createMidiClipFromSelection method which handles everything internally
        if !projectViewModel.midiViewModel.createMidiClipFromSelection() {
            // Handle failure - maybe show an alert in a real app
            print("Failed to create MIDI clip - selection might not be on a MIDI track or other error")
        }
    }
    
    // Select track below current selection
    private func selectTrackBelow() {
        // If there are no tracks, do nothing
        if projectViewModel.tracks.isEmpty {
            return
        }
        
        // If no track is currently selected, select the first track
        guard let currentTrackId = projectViewModel.selectedTrackId,
              let currentIndex = projectViewModel.tracks.firstIndex(where: { $0.id == currentTrackId }) else {
            // No track selected, select the first track
            let firstTrackId = projectViewModel.tracks.first?.id
            projectViewModel.selectTrack(id: firstTrackId)
            
            if !timelineState.selectionActive {
                // Create a default selection at beat 0
                timelineState.selectionActive = true
                timelineState.selectionStartBeat = 0
                timelineState.selectionEndBeat = 4
            }
            return
        }
        
        // Calculate the next track index (cycling if at the end)
        let nextIndex = (currentIndex + 1) % projectViewModel.tracks.count
        let nextTrackId = projectViewModel.tracks[nextIndex].id
        
        // Update selection to the next track, keeping the same beat range
        let (startBeat, endBeat) = timelineState.normalizedSelectionRange
        
        timelineState.selectionActive = true
        projectViewModel.selectTrack(id: nextTrackId)
        timelineState.selectionStartBeat = startBeat
        timelineState.selectionEndBeat = endBeat
    }
    
    // Select track above current selection
    private func selectTrackAbove() {
        // If there are no tracks, do nothing
        if projectViewModel.tracks.isEmpty {
            return
        }
        
        // If no track is currently selected, select the last track
        guard let currentTrackId = projectViewModel.selectedTrackId,
              let currentIndex = projectViewModel.tracks.firstIndex(where: { $0.id == currentTrackId }) else {
            // No track selected, select the last track
            projectViewModel.selectTrack(id: projectViewModel.tracks.last?.id)
            if !timelineState.selectionActive {
                // Create a default selection at beat 0
                timelineState.selectionActive = true
                timelineState.selectionStartBeat = 0
                timelineState.selectionEndBeat = 4
            }
            return
        }
        
        // Calculate the previous track index (cycling if at the beginning)
        let previousIndex = currentIndex == 0 ? projectViewModel.tracks.count - 1 : currentIndex - 1
        let previousTrackId = projectViewModel.tracks[previousIndex].id
        
        // Update selection to the previous track, keeping the same beat range
        let (startBeat, endBeat) = timelineState.normalizedSelectionRange
        
        timelineState.selectionActive = true
        projectViewModel.selectTrack(id: previousTrackId)
        timelineState.selectionStartBeat = startBeat
        timelineState.selectionEndBeat = endBeat
    }
    
    // Delete/trim selection
    private func deleteSelection() {
        // Use the MenuCoordinator's deleteSelectedClip method
        menuCoordinator.deleteSelectedClip()
    }
}

#Preview {
    TimelineButtons(
        projectViewModel: ProjectViewModel(),
        timelineState: TimelineStateViewModel()
    )
}
