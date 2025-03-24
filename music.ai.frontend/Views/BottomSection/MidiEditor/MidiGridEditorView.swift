import SwiftUI

struct MidiGridEditorView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var viewModel: MidiEditorViewModel
    @State private var showDebugOverlay: Bool = false // For development only
    @State private var isDragging: Bool = false
    @State private var currentDragColumn: Int? = nil // Track which column we're currently drawing in
    
    // Track and clip IDs for looking up the clip
    let trackId: UUID
    let clipId: UUID
    
    // Computed property to get the current clip from the project
    private var midiClip: MidiClip? {
        guard let projectViewModel = viewModel.projectViewModel,
              let track = projectViewModel.tracks.first(where: { $0.id == trackId }),
              let clip = track.midiClips.first(where: { $0.id == clipId }) else {
            return nil
        }
        return clip
    }
    
    // Initialize with track and clip IDs
    init(viewModel: MidiEditorViewModel, trackId: UUID, clipId: UUID) {
        self.viewModel = viewModel
        self.trackId = trackId
        self.clipId = clipId
    }
    
    // Helper function to calculate note position from a point
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
    
    // Helper function to add or update note
    private func addOrUpdateNote(at position: (pitch: Int, beat: Double), in clip: MidiClip) {
        // Get the grid column for the current beat position
        let column = Int(position.beat * Double(viewModel.gridDivision.divisionsPerBeat))
        
        // If we're already drawing in this column and it's not a new column, return
        if let currentColumn = currentDragColumn, currentColumn == column {
            // Update the existing note's pitch
            if let existingNote = clip.notes.first(where: { Int($0.startBeat * Double(viewModel.gridDivision.divisionsPerBeat)) == column }) {
                var updatedClip = clip
                if let noteIndex = updatedClip.notes.firstIndex(where: { $0.id == existingNote.id }) {
                    updatedClip.notes[noteIndex].pitch = position.pitch
                    if let projectViewModel = viewModel.projectViewModel {
                        projectViewModel.updateMidiClip(updatedClip)
                    }
                }
            }
            return
        }
        
        // Set current column
        currentDragColumn = column
        
        // Check if there's already a note at this exact position and pitch
        let existingNoteAtPosition = clip.notes.first { note in
            let noteColumn = Int(note.startBeat * Double(viewModel.gridDivision.divisionsPerBeat))
            return noteColumn == column && note.pitch == position.pitch
        }
        
        // If there's already a note at this position and pitch, don't add a new one
        if existingNoteAtPosition != nil {
            print("DEBUG - Note already exists at position \(position.beat) with pitch \(position.pitch)")
            return
        }
        
        // Remove any existing note in this column with a different pitch
        var updatedClip = clip
        updatedClip.notes.removeAll { note in
            Int(note.startBeat * Double(viewModel.gridDivision.divisionsPerBeat)) == column
        }
        
        // Add the new note
        let defaultDuration = 1.0 / Double(viewModel.gridDivision.divisionsPerBeat)
        let updatedClipWithNewNote = viewModel.addNoteToClip(
            updatedClip,
            pitch: position.pitch,
            startBeat: position.beat,
            duration: defaultDuration
        )
        
        // Update the clip in the project
        if let projectViewModel = viewModel.projectViewModel {
            projectViewModel.updateMidiClip(updatedClipWithNewNote)
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Grid lines layer
                Canvas { context, size in
                    // Draw background
                    let backgroundRect = Path(CGRect(origin: .zero, size: size))
                    context.fill(backgroundRect, with: .color(themeManager.tertiaryBackgroundColor))
                    
                    // Calculate dimensions
                    let keyHeight = viewModel.getKeyHeight()
                    let totalNotes = viewModel.fullEndNote - viewModel.fullStartNote + 1
                    
                    // Draw horizontal lines (pitch divisions)
                    for i in 0...totalNotes {
                        let y = CGFloat(i) * keyHeight
                        let path = Path { p in
                            p.move(to: CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: size.width, y: y))
                        }
                        
                        // Black keys have darker background
                        if i < totalNotes {
                            let pitch = viewModel.fullEndNote - i
                            let isBlackKey = [1, 3, 6, 8, 10].contains(pitch % 12)
                            if isBlackKey {
                                let rect = CGRect(x: 0, y: y, width: size.width, height: keyHeight)
                                context.fill(Path(rect), with: .color(themeManager.gridLineColor.opacity(0.1)))
                            }
                        }
                        
                        context.stroke(path, with: .color(themeManager.gridLineColor.opacity(0.3)), lineWidth: 0.5)
                    }
                    
                    // Draw vertical lines (beat divisions)
                    if let clip = midiClip {
                        let clipDurationInBeats = clip.duration
                        let numberOfBars = Int(ceil(clipDurationInBeats / Double(viewModel.beatsPerBar)))
                        
                        for barIndex in 0...numberOfBars {
                            // Bar lines
                            let barX = CGFloat(barIndex * viewModel.beatsPerBar) * viewModel.pixelsPerBeat
                            let barPath = Path { p in
                                p.move(to: CGPoint(x: barX, y: 0))
                                p.addLine(to: CGPoint(x: barX, y: size.height))
                            }
                            context.stroke(barPath, with: .color(themeManager.gridLineColor.opacity(0.6)), lineWidth: 1)
                            
                            // Beat and division lines within each bar
                            if barIndex < numberOfBars {
                                // Beat lines
                                for beatIndex in 1..<viewModel.beatsPerBar {
                                    let beatX = barX + CGFloat(beatIndex) * viewModel.pixelsPerBeat
                                    let beatPath = Path { p in
                                        p.move(to: CGPoint(x: beatX, y: 0))
                                        p.addLine(to: CGPoint(x: beatX, y: size.height))
                                    }
                                    context.stroke(beatPath, with: .color(themeManager.gridLineColor.opacity(0.4)), lineWidth: 0.5)
                                }
                                
                                // Division lines
                                let divisionsPerBeat = viewModel.gridDivision.divisionsPerBeat
                                if divisionsPerBeat > 1 {
                                    for beatIndex in 0..<viewModel.beatsPerBar {
                                        for divIndex in 1..<divisionsPerBeat {
                                            let divX = barX + (CGFloat(beatIndex) + CGFloat(divIndex) / CGFloat(divisionsPerBeat)) * viewModel.pixelsPerBeat
                                            let divPath = Path { p in
                                                p.move(to: CGPoint(x: divX, y: 0))
                                                p.addLine(to: CGPoint(x: divX, y: size.height))
                                            }
                                            context.stroke(divPath, with: .color(themeManager.gridLineColor.opacity(0.2)), lineWidth: 0.5)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                // MIDI Notes layer
                if let clip = midiClip {
                    // Show clip notes
                    ForEach(clip.notes) { note in
                        MidiNoteView(note: note, viewModel: viewModel)
                            .id(note.id)
                    }
                }
                
                // Debug overlay (toggle with 'D' key)
                if showDebugOverlay {
                    GeometryReader { geo in
                        ZStack {
                            // Origin marker
                            Circle()
                                .fill(Color.red)
                                .frame(width: 10, height: 10)
                                .position(x: 0, y: 0)
                            
                            // Center marker
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 10, height: 10)
                                .position(x: geo.size.width/2, y: geo.size.height/2)
                            
                            // Grid measurements
                            Text("Width: \(Int(geo.size.width)), Height: \(Int(geo.size.height))")
                                .foregroundColor(.red)
                                .position(x: geo.size.width/2, y: 20)
                        }
                    }
                }
                
                // Interaction layer
                if let clip = midiClip {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            viewModel.isDrawModeEnabled ?
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    print("DEBUG - Draw mode drag detected")
                                    isDragging = true
                                    
                                    // Get mouse location in screen coordinates
                                    let mouseLocation = NSEvent.mouseLocation
                                    print("DEBUG - Mouse Location (screen): \(mouseLocation)")
                                    
                                    // Convert screen coordinates to window coordinates
                                    if let window = NSApp.keyWindow {
                                        let windowPoint = window.convertPoint(fromScreen: mouseLocation)
                                        print("DEBUG - Window Point: \(windowPoint)")
                                        
                                        // Convert window coordinates to view coordinates
                                        if let nsView = window.contentView?.hitTest(windowPoint),
                                           let scrollView = nsView.enclosingScrollView {
                                            let viewPoint = nsView.convert(windowPoint, from: nil)
                                            print("DEBUG - View Point: \(viewPoint)")
                                            
                                            // Calculate the note position
                                            if let position = getNotePosition(
                                                from: viewPoint,
                                                in: nsView,
                                                scrollView: scrollView
                                            ) {
                                                print("DEBUG - Adding/updating note at pitch: \(position.pitch), beat: \(position.beat)")
                                                addOrUpdateNote(at: position, in: clip)
                                            }
                                        }
                                    }
                                }
                                .onEnded { _ in
                                    print("DEBUG - Draw mode drag ended")
                                    isDragging = false
                                    currentDragColumn = nil
                                }
                            : nil
                        )
                        .onTapGesture(count: 2) { location in
                            guard !viewModel.isDrawModeEnabled else { return }
                            print("DEBUG - Double tap detected in normal mode")
                            
                            // Get mouse location in screen coordinates
                            let mouseLocation = NSEvent.mouseLocation
                            print("DEBUG - Mouse Location (screen): \(mouseLocation)")
                            
                            // Convert screen coordinates to window coordinates
                            if let window = NSApp.keyWindow {
                                let windowPoint = window.convertPoint(fromScreen: mouseLocation)
                                print("DEBUG - Window Point: \(windowPoint)")
                                
                                // Convert window coordinates to view coordinates
                                if let nsView = window.contentView?.hitTest(windowPoint),
                                   let scrollView = nsView.enclosingScrollView {
                                    let viewPoint = nsView.convert(windowPoint, from: nil)
                                    print("DEBUG - View Point: \(viewPoint)")
                                    
                                    // Calculate note position directly
                                    if let position = getNotePosition(
                                        from: viewPoint,
                                        in: nsView,
                                        scrollView: scrollView
                                    ) {
                                        print("DEBUG - Adding note at pitch: \(position.pitch), beat: \(position.beat)")
                                        
                                        // Check if there's already a note at this position and pitch
                                        let column = Int(position.beat * Double(viewModel.gridDivision.divisionsPerBeat))
                                        let existingNoteAtPosition = clip.notes.first { note in
                                            let noteColumn = Int(note.startBeat * Double(viewModel.gridDivision.divisionsPerBeat))
                                            return noteColumn == column && note.pitch == position.pitch
                                        }
                                        
                                        // If there's already a note at this position and pitch, don't add a new one
                                        if existingNoteAtPosition != nil {
                                            print("DEBUG - Note already exists at position \(position.beat) with pitch \(position.pitch)")
                                            return
                                        }
                                        
                                        // Set duration based on grid division
                                        let defaultDuration = 1.0 / Double(viewModel.gridDivision.divisionsPerBeat)
                                        
                                        let updatedClip = viewModel.addNoteToClip(
                                            clip,
                                            pitch: position.pitch,
                                            startBeat: position.beat,
                                            duration: defaultDuration
                                        )
                                        
                                        // Update the clip in the project
                                        if let projectViewModel = viewModel.projectViewModel {
                                            projectViewModel.updateMidiClip(updatedClip)
                                        }
                                    }
                                }
                            }
                        }
                }
            }
            .frame(width: midiClip.map { viewModel.calculateGridWidth(clipDuration: $0.duration) } ?? geometry.size.width)
            .onKeyPress("d") { 
                showDebugOverlay.toggle()
                return .handled
            }
        }
        .frame(height: viewModel.calculatePianoRollContentHeight())
    }
}

struct MidiNoteView: View {
    let note: MidiNote
    @ObservedObject var viewModel: MidiEditorViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
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
                    .stroke(themeManager.accentColor, lineWidth: 1)
            )
            .position(x: startX + width/2, y: y + keyHeight/2)
            // Observe both zoom levels for animations
            .animation(.easeInOut(duration: 0.2), value: viewModel.zoomLevel)
            .animation(.easeInOut(duration: 0.2), value: viewModel.horizontalZoomLevel)
    }
}

// Add a new view model to handle clip updates
class MidiClipViewModel: ObservableObject {
    @Published var clip: MidiClip
    
    init(clip: MidiClip) {
        self.clip = clip
    }
    
    func updateClip(_ newClip: MidiClip) {
        self.clip = newClip
    }
} 
