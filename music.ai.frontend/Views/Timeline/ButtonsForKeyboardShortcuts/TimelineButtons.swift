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
    
    // Event monitor for custom keyboard shortcuts
    @State private var eventMonitor: Any?
    
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
            
            // Copy selection (cmd C)
            Button(action: {
                copySelection()
            }) {
                EmptyView()
            }
            .keyboardShortcut("c", modifiers: [.command])
            
            // Paste at current position (cmd V)
            Button(action: {
                print("pasting")
                pasteAtCurrentPosition()
                
            }) {
                EmptyView()
            }
            .keyboardShortcut("v", modifiers: [.command])
            
            // Move playhead left (left arrow key)
            Button(action: {
                movePlayheadLeft()
            }) {
                EmptyView()
            }
            .keyboardShortcut(.leftArrow, modifiers: [])
            
            // Move playhead right (right arrow key)
            Button(action: {
                movePlayheadRight()
            }) {
                EmptyView()
            }
            .keyboardShortcut(.rightArrow, modifiers: [])
            
            // Duplicate Clips / Selection (cmd d)
            Button(action: {
                print("duplicating")
                duplicateSelection()
            }) {
                EmptyView()
            }
            .keyboardShortcut("d", modifiers: [.command])
            
            // Split Clips (cmd e)
            Button(action: {
                print("splitting")
                splitClip()
            }) {
                EmptyView()
            }
            .keyboardShortcut("e", modifiers: [.command])

        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .onAppear {
            // Set up NSEvent monitor for custom key handling
            setupKeyboardEventMonitor()
        }
        .onDisappear {
            // Clean up event monitor
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
                eventMonitor = nil
            }
        }
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
        let height: CGFloat = 70 // Default height for new tracks
        
        // print("🔍 TimelineButtons: Adding new \(type) track")
        // print("🔍 TimelineButtons: Current track count: \(projectViewModel.tracks.count)")
        // print("🔍 TimelineButtons: TimelineState selection active? \(timelineState.selectionActive)")
        // print("🔍 TimelineButtons: TimelineState selectionTrackId: \(timelineState.selectionTrackId?.uuidString ?? "nil")")
        // print("🔍 TimelineButtons: ProjectViewModel selectedTrackId: \(projectViewModel.selectedTrackId?.uuidString ?? "nil")")
        
        // If not, check if we have a selected track in the project view model
        if let trackId = projectViewModel.selectedTrackId,
                let selectedIndex = projectViewModel.tracks.firstIndex(where: { $0.id == trackId }) {
            // If a track is selected in the project view model, add the new track after it
            // print("✅ TimelineButtons: Found selected track in ProjectViewModel at index \(selectedIndex), adding new track after it")
            projectViewModel.addTrack(type: type, height: height, afterIndex: selectedIndex)
        }
        else {
            // If no track is selected anywhere, add to the end
            // print("⚠️ TimelineButtons: No track selected in either TimelineState or ProjectViewModel, adding to the end")
            projectViewModel.addTrack(type: type, height: height)
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
    
    // Copy selection
    private func copySelection() {
        // Use the MenuCoordinator's copySelectedClip method
        menuCoordinator.copySelectedClip()
    }
    
    // Paste at current position
    private func pasteAtCurrentPosition() {
        // Use the MenuCoordinator's pasteClip method
        menuCoordinator.pasteClip()
    }
    
    // Move playhead left (without selection)
    private func movePlayheadLeft() {
        // Cancel any existing selection
        timelineState.clearSelection()
        
        // Calculate new position based on grid division
        let currentPosition = projectViewModel.currentBeat
        var moveAmount: Double = 1.0
        
        // Adjust move amount based on grid division
        switch timelineState.gridDivision {
        case .sixteenth:
            moveAmount = 0.25
        case .eighth:
            moveAmount = 0.5
        case .quarter:
            moveAmount = 1.0
        case .half:
            moveAmount = 2.0
        case .bar:
            moveAmount = Double(projectViewModel.timeSignatureBeats)
        case .twoBar:
            moveAmount = Double(projectViewModel.timeSignatureBeats * 2)
        case .fourBar:
            moveAmount = Double(projectViewModel.timeSignatureBeats * 4)
        }
        
        // Calculate new position (ensure we don't go below 0)
        let newPosition = max(0, currentPosition - moveAmount)
        
        // Move playhead to new position
        projectViewModel.seekToBeat(newPosition)
    }
    
    // Move playhead right (without selection)
    private func movePlayheadRight() {
        // Cancel any existing selection
        timelineState.clearSelection()
        
        // Calculate new position based on grid division
        let currentPosition = projectViewModel.currentBeat
        var moveAmount: Double = 1.0
        
        // Adjust move amount based on grid division
        switch timelineState.gridDivision {
        case .sixteenth:
            moveAmount = 0.25
        case .eighth:
            moveAmount = 0.5
        case .quarter:
            moveAmount = 1.0
        case .half:
            moveAmount = 2.0
        case .bar:
            moveAmount = Double(projectViewModel.timeSignatureBeats)
        case .twoBar:
            moveAmount = Double(projectViewModel.timeSignatureBeats * 2)
        case .fourBar:
            moveAmount = Double(projectViewModel.timeSignatureBeats * 4)
        }
        
        // Calculate new position
        let newPosition = currentPosition + moveAmount
        
        // Move playhead to new position
        projectViewModel.seekToBeat(newPosition)
    }
    
    // Set up keyboard event monitor to handle Shift+arrow keys
    private func setupKeyboardEventMonitor() {
        // Remove existing monitor if any
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        
        // Create new monitor
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Check for Shift+Left Arrow
            if event.keyCode == 123 && event.modifierFlags.contains(.shift) {
                self.movePlayheadWithSelectionLeft()
                return nil // Consume the event
            }
            
            // Check for Shift+Right Arrow
            if event.keyCode == 124 && event.modifierFlags.contains(.shift) {
                self.movePlayheadWithSelectionRight()
                return nil // Consume the event
            }
            
            return event // Pass the event through if not handled
        }
    }
    
    // Move playhead left with selection
    private func movePlayheadWithSelectionLeft() {
        // Calculate new position based on grid division
        let currentPosition = projectViewModel.currentBeat
        var moveAmount: Double = 1.0
        
        // Adjust move amount based on grid division
        switch timelineState.gridDivision {
        case .sixteenth:
            moveAmount = 0.25
        case .eighth:
            moveAmount = 0.5
        case .quarter:
            moveAmount = 1.0
        case .half:
            moveAmount = 2.0
        case .bar:
            moveAmount = Double(projectViewModel.timeSignatureBeats)
        case .twoBar:
            moveAmount = Double(projectViewModel.timeSignatureBeats * 2)
        case .fourBar:
            moveAmount = Double(projectViewModel.timeSignatureBeats * 4)
        }
        
        // Calculate new position (ensure we don't go below 0)
        let newPosition = max(0, currentPosition - moveAmount)
        
        // If there's no selected track, we can't make a selection
        if let selectedTrackId = projectViewModel.selectedTrackId {
            if !timelineState.selectionActive {
                // Start a new selection from current to new position
                timelineState.startSelection(at: currentPosition, trackId: selectedTrackId)
                timelineState.updateSelection(to: newPosition)
            } else {
                // Extend the existing selection
                timelineState.updateSelection(to: newPosition)
            }
        }
        
        // Move playhead to new position
        projectViewModel.seekToBeat(newPosition)
    }
    
    // Move playhead right with selection
    private func movePlayheadWithSelectionRight() {
        // Calculate new position based on grid division
        let currentPosition = projectViewModel.currentBeat
        var moveAmount: Double = 1.0
        
        // Adjust move amount based on grid division
        switch timelineState.gridDivision {
        case .sixteenth:
            moveAmount = 0.25
        case .eighth:
            moveAmount = 0.5
        case .quarter:
            moveAmount = 1.0
        case .half:
            moveAmount = 2.0
        case .bar:
            moveAmount = Double(projectViewModel.timeSignatureBeats)
        case .twoBar:
            moveAmount = Double(projectViewModel.timeSignatureBeats * 2)
        case .fourBar:
            moveAmount = Double(projectViewModel.timeSignatureBeats * 4)
        }
        
        // Calculate new position
        let newPosition = currentPosition + moveAmount
        
        // If there's no selected track, we can't make a selection
        if let selectedTrackId = projectViewModel.selectedTrackId {
            if !timelineState.selectionActive {
                // Start a new selection from current to new position
                timelineState.startSelection(at: currentPosition, trackId: selectedTrackId)
                timelineState.updateSelection(to: newPosition)
            } else {
                // Extend the existing selection
                timelineState.updateSelection(to: newPosition)
            }
        }
        
        // Move playhead to new position
        projectViewModel.seekToBeat(newPosition)
    }

    private func duplicateSelection() {
        menuCoordinator.duplicateSelectedClip()
    }

    // Split clips at playhead or selection
    private func splitClip() {
        // Use the MenuCoordinator's splitClip method
        menuCoordinator.splitClip()
    }
}

#Preview {
    TimelineButtons(
        projectViewModel: ProjectViewModel(),
        timelineState: TimelineStateViewModel()
    )
}
