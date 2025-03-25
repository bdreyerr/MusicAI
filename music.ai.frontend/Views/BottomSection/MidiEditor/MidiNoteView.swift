//
//  MidiNoteView.swift
//  music.ai.frontend
//
//  Created by Ben Dreyer on 3/25/25.
//

import SwiftUI

struct MidiNoteView: View {
    let note: MidiNote
    @ObservedObject var viewModel: MidiEditorViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    // State for dragging
    @State private var isDragging: Bool = false
    @State private var dragOffset: CGSize = .zero
    @State private var dragStartLocation: CGPoint = .zero
    
    // Helper function to delete the note
    private func deleteNote() {
        // Get the current clip
        if let projectViewModel = viewModel.projectViewModel,
           let trackId = projectViewModel.selectedTrackId,
           let track = projectViewModel.tracks.first(where: { $0.id == trackId }),
           let clip = track.midiClips.first(where: { clip in
               clip.notes.contains(where: { $0.id == note.id })
           }) {
            // Create updated clip with the note removed
            let updatedClip = viewModel.removeNoteFromClip(clip, noteId: note.id)
            
            // Update the clip in the project
            projectViewModel.updateMidiClip(updatedClip)
        }
    }
    
    // Helper function to get note position from a point
    private func getNotePosition(from point: CGPoint, in nsView: NSView, scrollView: NSScrollView) -> (pitch: Int, beat: Double)? {
        let contentOffset = scrollView.contentView.bounds.origin
        
        // Adjust for scroll position and convert to grid coordinates
        let adjustedX = point.x + contentOffset.x
        
        // Calculate Y position relative to the grid
        let visibleY = point.y
        let adjustedY = visibleY + contentOffset.y
        
        // Calculate beat position with adjusted X
        let rawBeatPosition = viewModel.xToBeat(x: adjustedX)
        // Always snap to the nearest beat on the left
        let snappedBeatPosition = floor(rawBeatPosition * Double(viewModel.gridDivision.divisionsPerBeat)) / Double(viewModel.gridDivision.divisionsPerBeat)
        
        // Calculate pitch from adjusted Y position
        let keyHeight = viewModel.getKeyHeight()
        
        // Calculate note index from Y position
        // Flip the Y coordinate system (subtract from view height)
        let flippedY = nsView.bounds.height - adjustedY
        let noteIndex = Int(flippedY / keyHeight)
        // Calculate pitch (MIDI note number)
        let pitch = viewModel.fullStartNote + noteIndex
        
        // Validate pitch range
        guard pitch >= viewModel.fullStartNote && pitch <= viewModel.fullEndNote else {
            return nil
        }
        
        return (pitch, snappedBeatPosition)
    }
    
    var body: some View {
        // Calculate start position
        let startX = viewModel.beatToX(beat: note.startBeat)
        // Calculate end position
        let endX = viewModel.beatToX(beat: note.startBeat + note.duration)
        // Width is the difference between end and start
        let width = endX - startX
        
        // Calculate vertical position based on current zoom level
        let keyHeight = viewModel.getKeyHeight()
        let y = CGFloat(viewModel.fullEndNote - note.pitch) * keyHeight
        
        RoundedRectangle(cornerRadius: min(4, keyHeight * 0.3))
            .fill(themeManager.accentColor.opacity(0.7))
            .frame(width: width, height: max(1, keyHeight - 2)) // Ensure minimum height of 1
            .overlay(
                RoundedRectangle(cornerRadius: min(4, keyHeight * 0.3))
                    .stroke(viewModel.isNoteSelected(note.id) ? Color.white : themeManager.accentColor, lineWidth: viewModel.isNoteSelected(note.id) ? 2 : 1)
            )
            .position(x: startX + width/2, y: y + keyHeight/2)
            .offset(isDragging ? dragOffset : .zero)
            .opacity(isDragging ? 0.7 : 1.0)
            // Observe both zoom levels for animations
            .animation(.easeInOut(duration: 0.2), value: viewModel.zoomLevel)
            .animation(.easeInOut(duration: 0.2), value: viewModel.horizontalZoomLevel)
            // Add gesture recognizers for note deletion and selection
            .onTapGesture(count: 2) {
                // Double click deletion (when draw mode is off)
                if !viewModel.isDrawModeEnabled {
                    deleteNote()
                }
            }
            .simultaneousGesture(
                TapGesture(count: 1)
                    .onEnded {
                        // Handle single click based on mode and shift key
                        if !viewModel.isDrawModeEnabled {
                            // Check if shift is being held
                            let isShiftPressed = NSEvent.modifierFlags.contains(.shift)
                            viewModel.toggleNoteSelection(note.id, isShiftPressed: isShiftPressed)
                        } else {
                            deleteNote()
                        }
                    }
            )
            // Add drag gesture with lower priority
            .highPriorityGesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        // Only check for draw mode now
                        guard !viewModel.isDrawModeEnabled else { return }
                        
                        // Set initial state on first detection
                        if !isDragging {
                            isDragging = true
                            dragStartLocation = value.startLocation
                            // Select the note if it's not already selected
                            if !viewModel.isNoteSelected(note.id) {
                                viewModel.toggleNoteSelection(note.id, isShiftPressed: false)
                            }
                        }
                        
                        // Get mouse location in screen coordinates
                        let mouseLocation = NSEvent.mouseLocation
                        
                        // Convert screen coordinates to window coordinates
                        if let window = NSApp.keyWindow {
                            let windowPoint = window.convertPoint(fromScreen: mouseLocation)
                            
                            // Convert window coordinates to view coordinates
                            if let nsView = window.contentView?.hitTest(windowPoint),
                               let scrollView = nsView.enclosingScrollView {
                                let viewPoint = nsView.convert(windowPoint, from: nil)
                                
                                // Calculate the note position
                                if let position = getNotePosition(
                                    from: viewPoint,
                                    in: nsView,
                                    scrollView: scrollView
                                ) {
                                    // Calculate grid-aligned position
                                    let newX = viewModel.beatToX(beat: position.beat)
                                    let keyHeight = viewModel.getKeyHeight()
                                    let pitchOffset = CGFloat(viewModel.fullEndNote - position.pitch)
                                    let newY = pitchOffset * keyHeight + keyHeight/2
                                    
                                    // Calculate current position - don't add width/2 to align with grid
                                    let currentX = startX
                                    let currentY = y + keyHeight/2
                                    
                                    dragOffset = CGSize(
                                        width: newX - currentX,
                                        height: newY - currentY
                                    )
                                }
                            }
                        }
                    }
                    .onEnded { value in
                        // Only process if we were actually dragging
                        if isDragging {
                            // Get mouse location in screen coordinates
                            let mouseLocation = NSEvent.mouseLocation
                            
                            // Convert screen coordinates to window coordinates
                            if let window = NSApp.keyWindow,
                               let projectViewModel = viewModel.projectViewModel,
                               let trackId = projectViewModel.selectedTrackId,
                               let track = projectViewModel.tracks.first(where: { $0.id == trackId }),
                               let clip = track.midiClips.first(where: { clip in
                                   clip.notes.contains(where: { $0.id == note.id })
                               }) {
                                let windowPoint = window.convertPoint(fromScreen: mouseLocation)
                                
                                // Convert window coordinates to view coordinates
                                if let nsView = window.contentView?.hitTest(windowPoint),
                                   let scrollView = nsView.enclosingScrollView {
                                    let viewPoint = nsView.convert(windowPoint, from: nil)
                                    
                                    // Calculate the final note position
                                    if let position = getNotePosition(
                                        from: viewPoint,
                                        in: nsView,
                                        scrollView: scrollView
                                    ) {
                                        // Update the note position in the clip
                                        let updatedClip = viewModel.updateNotePosition(
                                            clip,
                                            noteId: note.id,
                                            newStartBeat: position.beat,
                                            newPitch: position.pitch
                                        )
                                        
                                        // Update the clip in the project
                                        projectViewModel.updateMidiClip(updatedClip)
                                    }
                                }
                            }
                        }
                        
                        // Reset drag state
                        isDragging = false
                        dragOffset = .zero
                    }
            )
            .zIndex(isDragging ? 1000 : 100) // Ensure dragged note is above others
    }
}
