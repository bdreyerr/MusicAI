import SwiftUI

struct MidiVelocityEditorView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var viewModel: MidiEditorViewModel
    
    // Track and clip IDs for looking up the clip
    let trackId: UUID
    let clipId: UUID
    
    // State for dragging
    @State private var isDragging: Bool = false
    @State private var draggedNoteId: UUID? = nil
    @State private var dragStartLocation: CGPoint = .zero
    @State private var originalVelocity: Int = 0
    @State private var currentDragVelocity: Int = 0
    @State private var currentDragX: CGFloat = 0
    
    // State to force redraw
    @State private var updateTrigger = false
    
    // Constants
    private let dotSize: CGFloat = 8
    private let velocityRange: CGFloat = 127 // MIDI velocity range is 0-127
    
    // Computed property to get the current clip from the project
    private var midiClip: MidiClip? {
        guard let projectViewModel = viewModel.projectViewModel,
              let track = projectViewModel.tracks.first(where: { $0.id == trackId }),
              let clip = track.midiClips.first(where: { $0.id == clipId }) else {
            return nil
        }
        return clip
    }
    
    // Helper function to calculate y position from velocity
    private func yPositionForVelocity(_ velocity: Int, in height: CGFloat) -> CGFloat {
        return (CGFloat(velocity) / velocityRange) * height
    }
    
    // Helper function to calculate grid line velocity
    private func velocityForGridLine(_ index: Int) -> Int {
        return Int((3 - index) * (127 / 3))
    }
    
    // Helper function to calculate velocity from y position
    private func velocityFromDrag(startY: CGFloat, currentY: CGFloat, height: CGFloat) -> Int {
        let dragDelta = startY - currentY
        let velocityDelta = Int((dragDelta / height) * velocityRange)
        let newVelocity = originalVelocity + velocityDelta
        return max(0, min(127, newVelocity))
    }
    
    var body: some View {
        GeometryReader { geometry in
            if let clip = midiClip {
                ZStack {
                    // Background grid lines
                    VStack(spacing: 0) {
                        ForEach(0..<4) { i in
                            let velocity = velocityForGridLine(i)
                            Rectangle()
                                .fill(Color.clear)
                                .frame(height: geometry.size.height / 4)
                                .overlay(
                                    Rectangle()
                                        .fill(themeManager.gridLineColor.opacity(0.3))
                                        .frame(height: 0.5),
                                    alignment: .top
                                )
                                .overlay(
                                    Text("\(velocity)")
                                        .font(.system(size: 9))
                                        .foregroundColor(themeManager.secondaryTextColor)
                                        .padding(.trailing, 4),
                                    alignment: .trailing
                                )
                        }
                    }
                    
                    // Preview line when dragging
                    if isDragging {
                        // Vertical line
                        Rectangle()
                            .fill(themeManager.accentColor.opacity(0.5))
                            .frame(width: 1)
                            .frame(height: geometry.size.height)
                            .position(x: currentDragX, y: geometry.size.height / 2)
                        
                        // Horizontal line at current velocity
                        Rectangle()
                            .fill(themeManager.accentColor.opacity(0.5))
                            .frame(width: geometry.size.width)
                            .frame(height: 1)
                            .position(x: geometry.size.width / 2, y: geometry.size.height - yPositionForVelocity(currentDragVelocity, in: geometry.size.height))
                        
                        // Velocity value label
                        Text("\(currentDragVelocity)")
                            .font(.system(size: 10))
                            .foregroundColor(themeManager.accentColor)
                            .padding(4)
                            .background(themeManager.secondaryBackgroundColor.opacity(0.8))
                            .cornerRadius(4)
                            .position(x: currentDragX + 20, y: geometry.size.height - yPositionForVelocity(currentDragVelocity, in: geometry.size.height) - 15)
                    }
                    
                    // Velocity dots for each note
                    ForEach(clip.notes) { note in
                        let xPosition = viewModel.beatToX(beat: note.startBeat)
                        
                        Button(action: {}) {
                            Circle()
                                .fill(viewModel.isNoteSelected(note.id) ? themeManager.accentColor : themeManager.primaryTextColor)
                                .frame(width: dotSize, height: dotSize)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .position(x: xPosition, y: geometry.size.height - yPositionForVelocity(note.velocity, in: geometry.size.height))
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 1)
                                .onChanged { value in
                                    if !isDragging {
                                        isDragging = true
                                        draggedNoteId = note.id
                                        dragStartLocation = value.startLocation
                                        originalVelocity = note.velocity
                                        currentDragX = xPosition
                                    }
                                    
                                    if draggedNoteId == note.id {
                                        // Calculate new velocity based on drag
                                        let newVelocity = velocityFromDrag(
                                            startY: dragStartLocation.y,
                                            currentY: value.location.y,
                                            height: geometry.size.height
                                        )
                                        currentDragVelocity = newVelocity
                                        
                                        // Select the note if it's not already selected
                                        if !viewModel.isNoteSelected(note.id) {
                                            viewModel.selectedNotes = [note.id]
                                        }
                                        
                                        // Update all selected notes if this note is part of a selection
                                        if viewModel.selectedNotes.contains(note.id) {
                                            for selectedNoteId in viewModel.selectedNotes {
                                                if let selectedNote = clip.notes.first(where: { $0.id == selectedNoteId }) {
                                                    updateNoteVelocity(clip: clip, noteId: selectedNoteId, newVelocity: newVelocity)
                                                }
                                            }
                                        } else {
                                            // Update just this note
                                            updateNoteVelocity(clip: clip, noteId: note.id, newVelocity: newVelocity)
                                        }
                                    }
                                }
                                .onEnded { _ in
                                    isDragging = false
                                    draggedNoteId = nil
                                    // Force a redraw
                                    updateTrigger.toggle()
                                }
                        )
                    }
                }
            }
        }
        // Force view updates when clip changes
        .id(updateTrigger)
        // Listen for changes to the clip's notes
        .onChange(of: midiClip?.notes) { _, _ in
            updateTrigger.toggle()
        }
    }
    
    // Helper function to update a note's velocity
    private func updateNoteVelocity(clip: MidiClip, noteId: UUID, newVelocity: Int) {
        var updatedClip = clip
        if let noteIndex = updatedClip.notes.firstIndex(where: { $0.id == noteId }) {
            updatedClip.notes[noteIndex].velocity = newVelocity
            viewModel.projectViewModel?.updateMidiClip(updatedClip)
        }
    }
} 