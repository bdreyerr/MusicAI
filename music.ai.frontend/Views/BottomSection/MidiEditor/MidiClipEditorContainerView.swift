//
//  MidiClipEditorContainerView.swift
//  music.ai.frontend
//
//  Created by Ben Dreyer on 3/23/25.
//

import SwiftUI

struct MidiClipEditorContainerView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject var midiEditorViewModel = MidiEditorViewModel()
    
    // MIDI clip to be edited
    var midiClip: MidiClip?
    
    // Scroll position state
    @State private var verticalScrollOffset: CGFloat = 0
    
    // Constants for layout
    private let pianoRollWidth: CGFloat = 100
    private let velocityEditorHeight: CGFloat = 60
    private let controlsHeight: CGFloat = 30
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 0) {
                    // Top control area with zoom and grid controls
                    HStack {
                        // Zoom controls
                        HStack(spacing: 4) {
                            Button(action: midiEditorViewModel.zoomOut) {
                                Image(systemName: "minus.magnifyingglass")
                                    .foregroundColor(themeManager.primaryTextColor)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            .disabled(midiEditorViewModel.zoomLevel <= 0)
                            .padding(.horizontal, 4)
                            
                            Text("Zoom: \(midiEditorViewModel.zoomLevel + 1)/\(midiEditorViewModel.zoomMultipliers.count)")
                                .font(.system(size: 10))
                                .foregroundColor(themeManager.secondaryTextColor)
                            
                            Button(action: midiEditorViewModel.zoomIn) {
                                Image(systemName: "plus.magnifyingglass")
                                    .foregroundColor(themeManager.primaryTextColor)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            .disabled(midiEditorViewModel.zoomLevel >= midiEditorViewModel.zoomMultipliers.count - 1)
                            .padding(.horizontal, 4)
                        }
                        
                        Spacer()
                        
                        // Grid division selection
                        HStack(spacing: 4) {
                            Text("Grid:")
                                .font(.system(size: 10))
                                .foregroundColor(themeManager.secondaryTextColor)
                            
                            Picker("", selection: $midiEditorViewModel.gridDivision) {
                                ForEach(MidiEditorViewModel.GridDivision.allCases, id: \.self) { division in
                                    Text(division.label)
                                        .font(.system(size: 10))
                                        .tag(division)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(width: 60)
                            .labelsHidden()
                        }
                        .padding(.horizontal, 8)
                    }
                    .padding(.horizontal, 8)
                    .frame(height: controlsHeight)
                    .background(themeManager.tertiaryBackgroundColor)
                
                    // Main content area with piano roll and grid in shared scroll view
                    ScrollView(.vertical, showsIndicators: true) {
                        HStack(spacing: 0) {
                            // Piano roll keys (without its internal scroll view)
                            PianoRollKeysOnly(
                                viewModel: midiEditorViewModel, midiClip: midiClip
                            )
                            .frame(width: pianoRollWidth)
                            .border(themeManager.secondaryBorderColor, width: 0.5)
                            
                            // Grid area (horizontal scroll only)
                            ScrollView(.horizontal, showsIndicators: true) {
                                VStack(spacing: 0) {
                                    // Grid ruler
                                    GridRulerView(viewModel: midiEditorViewModel, midiClip: midiClip)
                                        .frame(height: controlsHeight)
                                        .border(themeManager.secondaryBorderColor, width: 0.5)
                                    
                                    // Grid content matching piano roll height
                                    GridContentView(viewModel: midiEditorViewModel, midiClip: midiClip)
                                        .frame(
                                            width: midiClip != nil 
                                                ? midiEditorViewModel.calculateGridWidth(clipDuration: midiClip!.duration)
                                                : 600,
                                            height: midiEditorViewModel.calculatePianoRollContentHeight()
                                        )
                                }
                            }
                            .border(themeManager.secondaryBorderColor, width: 0.5)
                        }
                    }
                    .frame(height: geometry.size.height - controlsHeight - velocityEditorHeight)
                    
                    // Velocity editor (extracted from PianoRoll)
                    HStack(spacing: 0) {
                        // Velocity label
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(themeManager.tertiaryBackgroundColor)
                            
                            Text("Velocity")
                                .font(.system(size: 8))
                                .fontWeight(.medium)
                                .foregroundColor(themeManager.primaryTextColor)
                                .padding(.leading, 4)
                        }
                        .frame(width: pianoRollWidth)
                        .border(themeManager.secondaryBorderColor, width: 0.5)
                        
                        // Max velocity indicator
                        ZStack(alignment: .trailing) {
                            Rectangle()
                                .fill(themeManager.tertiaryBackgroundColor)
                            
                            Text("127")
                                .font(.system(size: 11))
                                .foregroundColor(themeManager.primaryTextColor)
                                .padding(.trailing, 4)
                        }
                        .border(themeManager.secondaryBorderColor, width: 0.5)
                    }
                    .frame(height: velocityEditorHeight)
                }
                
                // Keyboard shortcuts layer (invisible)
                KeyboardShortcutsBottomSection()
                    .environmentObject(midiEditorViewModel)
                    .frame(width: 0, height: 0)
            }
        }
        .environmentObject(midiEditorViewModel)
    }
}

// Grid Ruler View for displaying bars, beats, and time divisions
struct GridRulerView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var viewModel: MidiEditorViewModel
    
    var midiClip: MidiClip?
    
    var body: some View {
        Canvas { context, size in
            // Background
            let backgroundRect = Path(CGRect(origin: .zero, size: size))
            context.fill(backgroundRect, with: .color(themeManager.tertiaryBackgroundColor))
            
            guard let clip = midiClip else { return }
            
            // Calculate constants for drawing
            let pixelsPerBeat = viewModel.pixelsPerBeat
            let beatsPerBar = viewModel.beatsPerBar
            let clipDurationInBeats = clip.duration
            let numberOfBars = Int(ceil(clipDurationInBeats / Double(beatsPerBar)))
            
            // Line heights
            let barLineHeight = size.height * 0.8
            let beatLineHeight = size.height * 0.6
            let divisionLineHeight = size.height * 0.4
            
            // Colors
            let barLineColor = themeManager.gridLineColor.opacity(0.8)
            let beatLineColor = themeManager.gridLineColor.opacity(0.6)
            let divisionLineColor = themeManager.gridLineColor.opacity(0.4)
            let textColor = themeManager.primaryTextColor
            
            // Draw bar lines and numbers
            for barIndex in 0...numberOfBars {
                let barPosition = Double(barIndex * beatsPerBar)
                let x = CGFloat(barPosition) * pixelsPerBeat
                
                // Bar line
                let barLinePath = Path { path in
                    path.move(to: CGPoint(x: x, y: size.height))
                    path.addLine(to: CGPoint(x: x, y: size.height - barLineHeight))
                }
                context.stroke(barLinePath, with: .color(barLineColor), lineWidth: 1.0)
                
                // Bar number
                let barNum = barIndex + 1 // 1-based bar numbers
                let textPosition = CGRect(x: x + 4, y: 2, width: 30, height: 14)
                context.draw(Text("\(barNum)").font(.system(size: 10)).foregroundColor(textColor),
                           in: textPosition)
                
                // Draw beat lines within each bar
                if barIndex < numberOfBars {
                    for beatIndex in 1..<beatsPerBar {
                        let beatPosition = barPosition + Double(beatIndex)
                        let beatX = CGFloat(beatPosition) * pixelsPerBeat
                        
                        // Beat line
                        let beatLinePath = Path { path in
                            path.move(to: CGPoint(x: beatX, y: size.height))
                            path.addLine(to: CGPoint(x: beatX, y: size.height - beatLineHeight))
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
                                    path.move(to: CGPoint(x: divX, y: size.height))
                                    path.addLine(to: CGPoint(x: divX, y: size.height - divisionLineHeight))
                                }
                                context.stroke(divLinePath, with: .color(divisionLineColor), lineWidth: 0.5)
                            }
                        }
                    }
                }
            }
        }
    }
}

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
            
            // Use localMidiClip if available, otherwise use midiClip from parent
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
            
            // Draw horizontal lines for each note
            for noteIndex in 0...noteRange {
                let y = CGFloat(noteIndex) * keyHeight
                
                // Horizontal line
                let horizontalLinePath = Path { path in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(horizontalLinePath, with: .color(horizontalLineColor), lineWidth: 0.5)
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
                        let previewWidth = CGFloat(noteDuration) * pixelsPerBeat
                        
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
            viewModel.hoveredKey = note
            viewModel.lastCenteredNote = note
            
            // Create a new note at this location if we have a clip
            if let clip = localMidiClip ?? midiClip {
                // Calculate beat position with snap
                let beatPosition = viewModel.snapToBeat(beat: viewModel.xToBeat(x: location.x))
                
                // Only add note if within clip bounds
                if beatPosition >= 0 && beatPosition < clip.duration {
                    // Use the viewModel to add the note and get the updated clip
                    localMidiClip = viewModel.addNoteToClip(
                        clip,
                        pitch: note,
                        startBeat: beatPosition,
                        duration: noteDuration,
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
                        viewModel.hoveredKey = note
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
                        
                        // Only create note if it has duration and is within clip bounds
                        if duration > 0 && startBeat >= 0 && endingBeat <= clip.duration {
                            // Use the viewModel to add the note and get the updated clip
                            localMidiClip = viewModel.addNoteToClip(
                                clip,
                                pitch: dragNote.pitch,
                                startBeat: startBeat,
                                duration: duration,
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
                    viewModel.hoveredKey = note
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
    }
}

// A modified version of PianoRoll that only renders the keys without internal scrolling
struct PianoRollKeysOnly: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var viewModel: MidiEditorViewModel
    
    var midiClip: MidiClip?
    
    // Width of the piano roll keys
    private let keyWidth: CGFloat = 100
    private let controlsHeight: CGFloat = 30
    
    // Piano note names
    private let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    
    var body: some View {
        // Calculate key height based on zoom
        let keyHeight = viewModel.getKeyHeight()
        let totalContentHeight = viewModel.calculatePianoRollContentHeight()
        
        
        VStack {
            // top area gap to allow space for ruler
            ZStack(alignment: .center) {
                Rectangle()
                    .fill(themeManager.tertiaryBackgroundColor)
            }
            .frame(height: controlsHeight)
            .border(themeManager.secondaryBorderColor, width: 0.5)
            
            // Stack for piano roll keys and labels
            HStack(spacing: 0) {
                // Labels section
                ZStack(alignment: .topLeading) {
                    // Background
                    Rectangle()
                        .fill(themeManager.tertiaryBackgroundColor)
                        .frame(height: totalContentHeight)
                    
                    // Octave labels
                    ForEach((0...10).reversed(), id: \.self) { octave in
                        let midiNote = octave * 12 // C notes: C-2, C-1, C0, etc.
                        if midiNote <= viewModel.fullEndNote && midiNote >= viewModel.fullStartNote {
                            // Calculate Y position
                            let yPosition = CGFloat(viewModel.fullEndNote - midiNote) * keyHeight
                            
                            // Only show octave labels
                            Text(getNoteName(midiNote: midiNote))
                                .font(.system(size: viewModel.getAdaptiveFontSize()))
                                .fontWeight(.medium)
                                .foregroundColor(themeManager.primaryTextColor)
                                .frame(width: 40, alignment: .leading)
                                .padding(.leading, 4)
                                .position(x: 40/2, y: yPosition + keyHeight/2)
                                .zIndex(1)
                            
                            // Line below each octave
                            Rectangle()
                                .fill(themeManager.secondaryBorderColor)
                                .frame(width: 40, height: 1)
                                .position(x: 40/2, y: yPosition + keyHeight)
                        }
                    }
                    
                    // Hover label
                    if let hoveredKey = viewModel.hoveredKey {
                        let yPosition = CGFloat(viewModel.fullEndNote - hoveredKey) * keyHeight
                        Text(getNoteName(midiNote: hoveredKey))
                            .font(.system(size: viewModel.getAdaptiveFontSize()))
                            .fontWeight(.medium)
                            .foregroundColor(themeManager.primaryTextColor)
                            .frame(width: 40, alignment: .leading)
                            .padding(.leading, 4)
                            .position(x: 40/2, y: yPosition + keyHeight/2)
                            .zIndex(2)
                    }
                }
                .frame(width: 40)
                .overlay(
                    Rectangle()
                        .fill(themeManager.secondaryBorderColor)
                        .frame(width: 1),
                    alignment: .trailing
                )
                
                // Piano keys
                ZStack(alignment: .topLeading) {
                    // Background
                    Rectangle()
                        .fill(themeManager.tertiaryBackgroundColor)
                        .frame(height: totalContentHeight)
                    
                    // Draw piano keys
                    ForEach(viewModel.fullStartNote...viewModel.fullEndNote, id: \.self) { noteNumber in
                        let isBlack = isBlackKey(noteNumber: noteNumber)
                        let yPosition = CGFloat(viewModel.fullEndNote - noteNumber) * keyHeight
                        
                        // Key area for hover detection and display
                        Rectangle()
                            .fill(isBlack ? Color.black : Color.white)
                            .frame(width: 60, height: max(1, keyHeight))  // Ensure minimum height
                            .overlay(
                                Group {
                                    // Show highlight when hovered
                                    if viewModel.hoveredKey == noteNumber {
                                        Rectangle()
                                            .fill(themeManager.accentColor.opacity(0.3))
                                    }
                                    
                                    // Bottom border
                                    Rectangle()
                                        .fill(themeManager.secondaryBorderColor)
                                        .frame(height: 1)
                                        .position(x: 60/2, y: keyHeight - 0.5)
                                }
                            )
                            .position(x: 60/2, y: yPosition + keyHeight/2)
                            .onTapGesture {
                                // When tapped, update both hover and last centered properties
                                viewModel.hoveredKey = noteNumber
                                viewModel.lastCenteredNote = noteNumber
                            }
                    }
                    
                    // Hover detection overlay
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(width: 60, height: totalContentHeight)
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                // Convert location to note number
                                let noteY = location.y
                                let noteIndex = Int((noteY / keyHeight).rounded(.down))
                                let calculatedNote = viewModel.fullEndNote - noteIndex
                                
                                // Ensure we're in valid range
                                if calculatedNote >= viewModel.fullStartNote && calculatedNote <= viewModel.fullEndNote {
                                    viewModel.hoveredKey = calculatedNote
                                    // Don't update lastCenteredNote during hover to prevent constant scrolling
                                }
                            case .ended:
                                viewModel.hoveredKey = nil
                            }
                        }
                }
                .frame(width: 60)
            }
            .frame(height: totalContentHeight)
            .onChange(of: viewModel.zoomLevel) { _, _ in
                // Scroll container will handle this via ancestors
            }
            .onChange(of: viewModel.hoveredKey) { _, _ in
                // External scroll handling should handle this
            }
        }
        
    }
    
    // Check if a note is a black key
    private func isBlackKey(noteNumber: Int) -> Bool {
        let note = noteNumber % 12
        return [1, 3, 6, 8, 10].contains(note)
    }
    
    // Convert MIDI note number to note name (e.g., C3, F#4)
    private func getNoteName(midiNote: Int) -> String {
        let octave = (midiNote / 12) - 1
        let noteIndex = midiNote % 12
        return "\(noteNames[noteIndex])\(octave)"
    }
}

#Preview {
    MidiClipEditorContainerView()
        .environmentObject(ThemeManager())
        .frame(width: 800, height: 600)
}
