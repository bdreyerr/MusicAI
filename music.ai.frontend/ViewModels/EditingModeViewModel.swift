import SwiftUI

/// Manages the current editing mode of the application
class EditingModeViewModel: ObservableObject {
    // TODO: Add ability to switch between modes so keyboard shortcuts work appropriately
    
    /// The different editing modes available in the application
    enum EditingMode {
        case timeline    // For timeline-level editing (clips, tracks, etc.)
        case midiEditor  // For MIDI note editing within a clip
    }
    
    /// The current editing mode
    @Published private(set) var currentMode: EditingMode = .timeline
    
    /// Switch to timeline editing mode
    func switchToTimelineMode() {
        if currentMode != .timeline {
            currentMode = .timeline
        }
    }
    
    /// Switch to MIDI editor mode
    func switchToMidiEditorMode() {
        if currentMode != .midiEditor {
            currentMode = .midiEditor
        }
    }
    
    /// Check if we're currently in timeline mode
    var isTimelineMode: Bool {
        currentMode == .timeline
    }
    
    /// Check if we're currently in MIDI editor mode
    var isMidiEditorMode: Bool {
        currentMode == .midiEditor
    }
}

/// Environment key for the editing mode
struct EditingModeKey: EnvironmentKey {
    static let defaultValue = EditingModeViewModel()
}

/// Environment value extension for easy access to the editing mode
extension EnvironmentValues {
    var editingMode: EditingModeViewModel {
        get { self[EditingModeKey.self] }
        set { self[EditingModeKey.self] = newValue }
    }
} 
