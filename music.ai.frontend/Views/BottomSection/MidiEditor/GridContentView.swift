//
//  GridContentView.swift
//  music.ai.frontend
//
//  Created by Ben Dreyer on 3/23/25.
//

import SwiftUI

// Grid Content View for displaying grid lines and MIDI notes
struct GridContentView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var viewModel: MidiEditorViewModel
    
    // State for tracking note interactions
    @State private var isHoveringGrid: Bool = false
    @State private var hoverLocation: CGPoint = .zero
    @State private var currentDragNote: (pitch: Int, startBeat: Double)? = nil
    @State private var noteDuration: Double = 1.0 // Default note duration of 1 beat
    
    // Use @State to hold locally updated MIDI clip
    @State private var localMidiClip: MidiClip?
    
    // MIDI clip passed from parent
    var midiClip: MidiClip? {
        didSet {
            // Update local copy when parent clip changes
            if let clip = midiClip {
                localMidiClip = clip
            }
        }
    }
    
    var body: some View {
        Canvas { context, size in
            // Background
            let backgroundRect = Path(CGRect(origin: .zero, size: size))
            context.fill(backgroundRect, with: .color(themeManager.secondaryBackgroundColor))
            
            guard let clip = localMidiClip ?? midiClip else { return }
            
            // Calculate constants for drawing
            let pixelsPerBeat = viewModel.pixelsPerBeat
            let beatsPerBar = viewModel.beatsPerBar
            let clipDurationInBeats = clip.duration
            let numberOfBars = Int(ceil(clipDurationInBeats / Double(beatsPerBar)))
            
            // Get key height for grid rows
            let keyHeight = viewModel.getKeyHeight()
            let noteRange = viewModel.fullEndNote - viewModel.fullStartNote + 1
            
            // Colors
            let barLineColor = themeManager.gridLineColor.opacity(0.5)
            let beatLineColor = themeManager.gridLineColor.opacity(0.3)
            let divisionLineColor = themeManager.gridLineColor.opacity(0.2)
            let horizontalLineColor = themeManager.gridLineColor.opacity(0.2)
            
            // Draw horizontal lines for each note - Draw these first (behind vertical lines)
            for noteIndex in 0...noteRange {
                // Calculate Y position based on note index (from top to bottom)
                let y = CGFloat(noteIndex) * keyHeight
                
                // Horizontal line
                let horizontalLinePath = Path { path in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(horizontalLinePath, with: .color(horizontalLineColor), lineWidth: 0.5)
            }
            
            // Draw vertical bar lines
            for barIndex in 0...numberOfBars {
                let barPosition = Double(barIndex * beatsPerBar)
                let x = CGFloat(barPosition) * pixelsPerBeat
                
                // Bar line
                let barLinePath = Path { path in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                }
                context.stroke(barLinePath, with: .color(barLineColor), lineWidth: 1.0)
                
                // Draw beat lines within each bar
                if barIndex < numberOfBars {
                    for beatIndex in 1..<beatsPerBar {
                        let beatPosition = barPosition + Double(beatIndex)
                        let beatX = CGFloat(beatPosition) * pixelsPerBeat
                        
                        // Beat line
                        let beatLinePath = Path { path in
                            path.move(to: CGPoint(x: beatX, y: 0))
                            path.addLine(to: CGPoint(x: beatX, y: size.height))
                        }
                        context.stroke(beatLinePath, with: .color(beatLineColor), lineWidth: 0.8)
                    }
                    
                    // Draw finer divisions based on grid division
                    let divisionsPerBeat = viewModel.gridDivision.divisionsPerBeat
                    if divisionsPerBeat > 1 {
                        for beatIndex in 0..<beatsPerBar {
                            for divIndex in 1..<divisionsPerBeat {
                                let divPosition = barPosition + Double(beatIndex) + Double(divIndex) / Double(divisionsPerBeat)
                                let divX = CGFloat(divPosition) * pixelsPerBeat
                                
                                // Division line
                                let divLinePath = Path { path in
                                    path.move(to: CGPoint(x: divX, y: 0))
                                    path.addLine(to: CGPoint(x: divX, y: size.height))
                                }
                                context.stroke(divLinePath, with: .color(divisionLineColor), lineWidth: 0.5)
                            }
                        }
                    }
                }
            }
            
            // If we have a hovered key, highlight that row
            if let hoveredKey = viewModel.hoveredKey {
                let noteY = CGFloat(viewModel.fullEndNote - hoveredKey) * keyHeight
                let highlightRect = Path(CGRect(x: 0, y: noteY, width: size.width, height: keyHeight))
                context.fill(highlightRect, with: .color(themeManager.accentColor.opacity(0.1)))
            }
            
            // Draw MIDI notes if available
            for note in clip.notes {
                let noteX = CGFloat(note.startBeat) * pixelsPerBeat
                let noteWidth = CGFloat(note.duration) * pixelsPerBeat
                let noteY = CGFloat(viewModel.fullEndNote - note.pitch) * keyHeight
                
                let noteRect = Path(CGRect(x: noteX, y: noteY, width: noteWidth, height: keyHeight))
                
                // Use clip color with alpha based on velocity
                let noteAlpha = 0.5 + (CGFloat(note.velocity) / 127.0) * 0.5
                let noteColor = (clip.color ?? themeManager.accentColor).opacity(noteAlpha)
                
                context.fill(noteRect, with: .color(noteColor))
                context.stroke(noteRect, with: .color(themeManager.primaryTextColor.opacity(0.8)), lineWidth: 1.0)
            }
            
            // Draw hover preview if active
            if isHoveringGrid {
                // Calculate the pitch and beat from hover position
                let hoverY = hoverLocation.y
                let hoverX = hoverLocation.x
                
                // Calculate nearest note based on hover position
                let noteIndex = Int(hoverY / keyHeight)
                let hoverNote = viewModel.fullEndNote - noteIndex
                
                // Ensure note is in valid range
                if hoverNote >= viewModel.fullStartNote && hoverNote <= viewModel.fullEndNote {
                    // Calculate the beat position with snap
                    let hoverBeat = viewModel.snapToBeat(beat: Double(hoverX) / Double(pixelsPerBeat))
                    
                    // Check if hover position is within clip bounds
                    if hoverBeat >= 0 && hoverBeat < clipDurationInBeats {
                        // Draw preview note
                        let noteY = CGFloat(viewModel.fullEndNote - hoverNote) * keyHeight
                        let noteX = CGFloat(hoverBeat) * pixelsPerBeat
                        
                        // Calculate preview width based on current grid division
                        let divisionDuration = 1.0 / Double(viewModel.gridDivision.divisionsPerBeat)
                        let previewWidth = CGFloat(divisionDuration) * pixelsPerBeat
                        
                        let previewRect = Path(CGRect(x: noteX, y: noteY, width: previewWidth, height: keyHeight))
                        context.fill(previewRect, with: .color(themeManager.accentColor.opacity(0.3)))
                        context.stroke(previewRect, with: .color(themeManager.accentColor.opacity(0.6)), lineWidth: 1.0)
                    }
                }
            }
            
            // Show drag preview if dragging a note
            if let dragNote = currentDragNote {
                let startX = CGFloat(dragNote.startBeat) * pixelsPerBeat
                let noteY = CGFloat(viewModel.fullEndNote - dragNote.pitch) * keyHeight
                let endX = hoverLocation.x
                
                // Calculate width based on drag direction
                let width = abs(endX - startX)
                let originX = min(startX, endX)
                
                let dragRect = Path(CGRect(x: originX, y: noteY, width: width, height: keyHeight))
                context.fill(dragRect, with: .color(themeManager.accentColor.opacity(0.4)))
                context.stroke(dragRect, with: .color(themeManager.accentColor.opacity(0.8)), lineWidth: 1.0)
            }
        }
        .contentShape(Rectangle()) // Make entire area interactive
        .onTapGesture { location in
            // Convert tap location to note and beat
            let noteIndex = Int(location.y / viewModel.getKeyHeight())
            let note = viewModel.fullEndNote - noteIndex
            
            // Update hovered key
            viewModel.updateHoveredKey(note)
            viewModel.lastCenteredNote = note
            
            // Create a new note at this location if we have a clip
            if let clip = localMidiClip ?? midiClip {
                // Calculate beat position with snap
                let beatPosition = viewModel.snapToBeat(beat: viewModel.xToBeat(x: location.x))
                
                // Only add note if within clip bounds
                if beatPosition >= 0 && beatPosition < clip.duration {
                    // Calculate note duration based on current grid division
                    let divisionDuration = 1.0 / Double(viewModel.gridDivision.divisionsPerBeat)
                    
                    // Use the viewModel to add the note and get the updated clip
                    localMidiClip = viewModel.addNoteToClip(
                        clip,
                        pitch: note,
                        startBeat: beatPosition,
                        duration: divisionDuration,
                        velocity: 80
                    )
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 5)
                .onChanged { value in
                    // Store hover location for preview
                    hoverLocation = value.location
                    
                    // If we're just starting the drag, initialize the note data
                    if currentDragNote == nil {
                        let noteIndex = Int(value.startLocation.y / viewModel.getKeyHeight())
                        let note = viewModel.fullEndNote - noteIndex
                        let beatPosition = viewModel.snapToBeat(beat: viewModel.xToBeat(x: value.startLocation.x))
                        
                        // Set up the current drag note
                        currentDragNote = (pitch: note, startBeat: beatPosition)
                        
                        // Update hover key for visual feedback
                        viewModel.updateHoveredKey(note)
                    }
                }
                .onEnded { value in
                    // Create a new note based on the drag if we have a clip
                    if let clip = localMidiClip ?? midiClip, let dragNote = currentDragNote {
                        let endBeat = viewModel.snapToBeat(beat: viewModel.xToBeat(x: value.location.x))
                        
                        // Calculate start and duration (handling dragging left or right)
                        let startBeat = min(dragNote.startBeat, endBeat)
                        let endingBeat = max(dragNote.startBeat, endBeat)
                        let duration = endingBeat - startBeat
                        
                        // For very small drags, use grid division as the default size
                        let divisionDuration = 1.0 / Double(viewModel.gridDivision.divisionsPerBeat)
                        let finalDuration = duration > 0.001 ? duration : divisionDuration
                        
                        // Only create note if it has duration and is within clip bounds
                        if finalDuration > 0 && startBeat >= 0 && endingBeat <= clip.duration {
                            // Use the viewModel to add the note and get the updated clip
                            localMidiClip = viewModel.addNoteToClip(
                                clip,
                                pitch: dragNote.pitch,
                                startBeat: startBeat,
                                duration: finalDuration,
                                velocity: 80
                            )
                        }
                    }
                    
                    // Reset drag state
                    currentDragNote = nil
                }
        )
        .onHover { isHovering in
            isHoveringGrid = isHovering
        }
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                hoverLocation = location
                
                // Update hovered key for vertical position
                let noteIndex = Int(location.y / viewModel.getKeyHeight())
                let note = viewModel.fullEndNote - noteIndex
                
                if note >= viewModel.fullStartNote && note <= viewModel.fullEndNote {
                    // Prevent multiple updates in the same frame by using the debounced method
                    viewModel.updateHoveredKey(note)
                }
            case .ended:
                // Don't reset hoveredKey here to keep the highlight when the mouse leaves
                break
            }
        }
        .onAppear {
            // Initialize local copy of the clip when view appears
            if let clip = midiClip {
                localMidiClip = clip
            }
        }
        .onChange(of: midiClip) { _, newClip in
            // Update local copy when parent clip changes
            if let clip = newClip {
                localMidiClip = clip
            }
        }
        .onChange(of: viewModel.midiClipDidUpdate) { _, _ in
            // Redraw when the clip is updated
        }
        .onChange(of: viewModel.horizontalZoomLevel) { _, _ in
            // Redraw when horizontal zoom changes
        }
        .onChange(of: viewModel.gridDivision) { _, _ in
            // Redraw when grid division changes
        }
    }
}
