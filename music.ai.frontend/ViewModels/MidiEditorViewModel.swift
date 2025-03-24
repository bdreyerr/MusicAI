import SwiftUI
import Combine

/// ViewModel for managing the state of the MIDI editor components
class MidiEditorViewModel: ObservableObject {
    // MARK: - Piano Roll Properties
    
    /// Current zoom level index (0-based)
    @Published var zoomLevel: Int = 1
    
    /// Available zoom multipliers for the piano roll
    let zoomMultipliers: [CGFloat] = [0.7, 1.0, 1.5]
    
    /// Font size multipliers corresponding to each zoom level
    let fontSizeMultipliers: [CGFloat] = [0.85, 1.0, 1.1]
    
    /// Base key height (at zoom level 1) in pixels
    let baseKeyHeight: CGFloat = 15
    
    /// The note being currently hovered in the piano roll
    @Published var hoveredKey: Int? = nil
    
    /// Debounce the hoveredKey updates
    private var hoveredKeyDebouncer: AnyCancellable?
    private var pendingHoveredKey: Int? = nil
    private let debounceDelay: TimeInterval = 0.01 // 50ms
    
    /// The last note that was centered in the view (for restoring position after zoom)
    @Published var lastCenteredNote: Int = 60 // Middle C by default
    
    // MARK: - MIDI Note Range
    
    /// Starting MIDI note (C-2)
    let fullStartNote = 0
    
    /// Ending MIDI note (C8)
    let fullEndNote = 108
    
    // MARK: - Grid Properties
    
    /// Horizontal grid zoom level (0-based)
    @Published var horizontalZoomLevel: Int = 1
    
    /// Available horizontal zoom multipliers for grid
    let horizontalZoomMultipliers: [CGFloat] = [0.5, 1.0, 1.5, 2.0]
    
    /// Base value for pixels per beat at zoom level 1
    let basePixelsPerBeat: CGFloat = 40
    
    /// Pixels per beat (quarter note) at the current horizontal zoom level
    var pixelsPerBeat: CGFloat {
        return basePixelsPerBeat * horizontalZoomMultipliers[horizontalZoomLevel]
    }
    
    /// Number of beats per bar (assuming 4/4 time signature for now)
    let beatsPerBar: Int = 4
    
    /// Grid snap division (e.g., 1/4, 1/8, 1/16 note)
    enum GridDivision: Int, CaseIterable {
        case whole = 1      // 1 division per bar
        case half = 2       // 2 divisions per bar
        case quarter = 4    // 4 divisions per bar (standard beat)
        case eighth = 8     // 8 divisions per bar
        case sixteenth = 16 // 16 divisions per bar
        
        var label: String {
            switch self {
            case .whole: return "1"
            case .half: return "1/2"
            case .quarter: return "1/4"
            case .eighth: return "1/8"
            case .sixteenth: return "1/16"
            }
        }
        
        var divisionsPerBeat: Int {
            return self.rawValue / 4
        }
    }
    
    /// Current grid division for snap
    @Published var gridDivision: GridDivision = .quarter
    
    // MARK: - MIDI Editing
    
    /// Signal to views when MIDI clip is updated
    @Published var midiClipDidUpdate: Bool = false
    
    // Store the currently edited clip
    private var editedClip: MidiClip?
    
    // MARK: - Zoom Methods
    
    /// Updates hoveredKey with debouncing to prevent multiple updates per frame
    func updateHoveredKey(_ newValue: Int?) {
        // Skip if no change
        if newValue == hoveredKey { return }
        
        // Store the pending update
        pendingHoveredKey = newValue
        
        // Cancel existing debouncer
        hoveredKeyDebouncer?.cancel()
        
        // Create new debouncer
        hoveredKeyDebouncer = Just(())
            .delay(for: .seconds(debounceDelay), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.hoveredKey = self.pendingHoveredKey
                }
            }
    }
    
    /// Increases the zoom level if not at maximum
    func zoomIn() {
        if zoomLevel < zoomMultipliers.count - 1 {
            // Store currently centered note if one is hovered
            if let hoveredKey = hoveredKey {
                lastCenteredNote = hoveredKey
            }
            zoomLevel += 1
        }
    }
    
    /// Decreases the zoom level if not at minimum
    func zoomOut() {
        if zoomLevel > 0 {
            // Store currently centered note if one is hovered
            if let hoveredKey = hoveredKey {
                lastCenteredNote = hoveredKey
            }
            zoomLevel -= 1
        }
    }
    
    /// Increases the horizontal zoom level if not at maximum
    func horizontalZoomIn() {
        if horizontalZoomLevel < horizontalZoomMultipliers.count - 1 {
            horizontalZoomLevel += 1
        }
    }
    
    /// Decreases the horizontal zoom level if not at minimum
    func horizontalZoomOut() {
        if horizontalZoomLevel > 0 {
            horizontalZoomLevel -= 1
        }
    }
    
    /// Calculates the current key height based on the zoom level
    func getKeyHeight() -> CGFloat {
        let height = baseKeyHeight * zoomMultipliers[zoomLevel]
        return max(1.0, height)  // Ensure minimum height
    }
    
    /// Calculates the total content height of the piano roll
    func calculatePianoRollContentHeight() -> CGFloat {
        return getKeyHeight() * CGFloat(fullEndNote - fullStartNote + 1)
    }
    
    /// Gets the appropriate font size for the current zoom level
    func getAdaptiveFontSize() -> CGFloat {
        let baseSize: CGFloat = 11
        return baseSize * fontSizeMultipliers[zoomLevel]
    }
    
    // MARK: - Grid Methods
    
    /// Calculates the total width needed for the grid based on clip duration
    func calculateGridWidth(clipDuration: Double) -> CGFloat {
        return max(600, CGFloat(clipDuration) * pixelsPerBeat)
    }
    
    /// Get pixels per division based on current grid division
    func getPixelsPerDivision() -> CGFloat {
        return pixelsPerBeat / CGFloat(gridDivision.divisionsPerBeat)
    }
    
    /// Converts a beat position to x coordinate
    func beatToX(beat: Double) -> CGFloat {
        return CGFloat(beat) * pixelsPerBeat
    }
    
    /// Converts an x coordinate to beat position
    func xToBeat(x: CGFloat) -> Double {
        return Double(x) / Double(pixelsPerBeat)
    }
    
    /// Calculates the snap value for a given beat position
    func snapToBeat(beat: Double) -> Double {
        let divisionsPerBeat = Double(gridDivision.divisionsPerBeat)
        let snapIncrement = 1.0 / divisionsPerBeat
        return round(beat / snapIncrement) * snapIncrement
    }
    
    // MARK: - MIDI Editing Methods
    
    /// Add a note to a MIDI clip
    func addNoteToClip(_ clip: MidiClip, pitch: Int, startBeat: Double, duration: Double, velocity: Int = 80) -> MidiClip {
        // Validate the note parameters
        guard pitch >= fullStartNote && pitch <= fullEndNote,
              startBeat >= 0 && startBeat < clip.duration,
              duration > 0 && startBeat + duration <= clip.duration,
              velocity >= 0 && velocity <= 127 else {
            print("⚠️ Invalid note parameters, not adding note")
            return clip
        }
        
        // Create the new note
        let newNote = MidiNote(
            pitch: pitch,
            startBeat: startBeat,
            duration: duration,
            velocity: velocity
        )
        
        // Create a new clip with the note added
        var updatedClip = clip
        updatedClip.notes.append(newNote)
        print("✅ Added note: pitch=\(pitch), start=\(startBeat), duration=\(duration)")
        
        // Signal the update
        midiClipDidUpdate = !midiClipDidUpdate
        
        return updatedClip
    }
    
    /// Remove a note from a MIDI clip
    func removeNoteFromClip(_ clip: MidiClip, noteId: UUID) -> MidiClip {
        var updatedClip = clip
        updatedClip.notes.removeAll { $0.id == noteId }
        
        // Signal the update
        midiClipDidUpdate = !midiClipDidUpdate
        
        return updatedClip
    }
    
    // MARK: - Navigation Methods
    
    /// Sets the current hovered note to middle C (C4, MIDI note 60)
    func goToMiddleC() {
        updateHoveredKey(60)
        lastCenteredNote = 60
    }
    
    /// Go to the C at the specified octave
    func goToOctave(_ octave: Int) {
        // Octave numbers in MIDI: -2 to 8
        // MIDI note numbers: C-2 is 0, C-1 is 12, C0 is 24, etc.
        let midiNote = (octave + 2) * 12
        
        // Make sure we're in range
        if midiNote >= fullStartNote && midiNote <= fullEndNote {
            updateHoveredKey(midiNote)
            lastCenteredNote = midiNote
        }
    }
    
    /// Scrolls to the next C note up
    func goToNextOctaveUp() {
        let currentNote = hoveredKey ?? lastCenteredNote
        
        // Find the current note's octave
        let currentOctave = (currentNote / 12)
        
        // Calculate the next C note up (next octave's C)
        let nextCNote = (currentOctave + 1) * 12
        
        // Make sure we're in range
        if nextCNote <= fullEndNote {
            updateHoveredKey(nextCNote)
            lastCenteredNote = nextCNote
        }
    }
    
    /// Scrolls to the next C note down
    func goToNextOctaveDown() {
        let currentNote = hoveredKey ?? lastCenteredNote
        
        // Find the current note's octave
        let currentOctave = (currentNote / 12)
        
        // Calculate the next C note down (previous octave's C)
        let previousCNote = (currentOctave - 1) * 12
        
        // Make sure we're in range
        if previousCNote >= fullStartNote {
            updateHoveredKey(previousCNote)
            lastCenteredNote = previousCNote
        }
    }
    
    /// Move the hover position up one note
    func moveHoverUp() {
        let currentNote = hoveredKey ?? lastCenteredNote
        if currentNote < fullEndNote {
            updateHoveredKey(currentNote + 1)
            lastCenteredNote = currentNote + 1
        }
    }
    
    /// Move the hover position down one note
    func moveHoverDown() {
        let currentNote = hoveredKey ?? lastCenteredNote
        if currentNote > fullStartNote {
            updateHoveredKey(currentNote - 1)
            lastCenteredNote = currentNote - 1
        }
    }
} 