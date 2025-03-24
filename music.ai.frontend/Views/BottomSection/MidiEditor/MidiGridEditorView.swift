import SwiftUI

struct MidiGridEditorView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var viewModel: MidiEditorViewModel
    @State private var showDebugOverlay: Bool = false // For development only
    
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
                        .onTapGesture(count: 2) { location in
                            if let event = NSApp.currentEvent {
                                // Get the location in the window
                                let windowLocation = event.locationInWindow
                                
                                // Convert window coordinates to view coordinates
                                if let nsView = NSApp.keyWindow?.contentView?.hitTest(windowLocation) {
                                    let viewLocation = nsView.convert(windowLocation, from: nil)
                                    
                                    // Calculate beat position
                                    let rawBeatPosition = viewModel.xToBeat(x: CGFloat(viewLocation.x))
                                    let snappedBeatPosition = viewModel.snapToBeat(beat: rawBeatPosition)
                                    
                                    // Calculate pitch from y position
                                    let keyHeight = viewModel.getKeyHeight()
                                    let noteIndex = Int(viewLocation.y / keyHeight)
                                    let pitch = viewModel.fullEndNote - noteIndex
                                    
                                    // Only add note if pitch is in valid range
                                    if pitch >= viewModel.fullStartNote && pitch <= viewModel.fullEndNote {
                                        // Add a note with default duration of 1 beat
                                        let defaultDuration = 1.0
                                        let updatedClip = viewModel.addNoteToClip(
                                            clip,
                                            pitch: pitch,
                                            startBeat: snappedBeatPosition,
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
    let viewModel: MidiEditorViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        // Calculate start position
        let startX = viewModel.beatToX(beat: note.startBeat)
        // Calculate end position
        let endX = viewModel.beatToX(beat: note.startBeat + note.duration)
        // Width is the difference between end and start
        let width = endX - startX
        
        // Calculate vertical position
        let keyHeight = viewModel.getKeyHeight()
        let y = CGFloat(viewModel.fullEndNote - note.pitch) * keyHeight
        let height = keyHeight - 2 // Slight padding
        
        RoundedRectangle(cornerRadius: 4)
            .fill(themeManager.accentColor.opacity(0.7))
            .frame(width: width, height: height)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(themeManager.accentColor, lineWidth: 1)
            )
            .position(x: startX + width/2, y: y + height/2)
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
