import SwiftUI
import Combine

/// TimelineState manages the visual representation and zoom behavior of the timeline.
/// This is separate from ProjectViewModel which manages the actual music project data.
class TimelineState: ObservableObject {
    @Published var zoomLevel: Double = 0.146 { // Default zoom level to match the old implementation
        didSet {
            // Notify that zoom level has changed
            zoomChanged = true
            
            // Reset the flag after a short delay to allow for multiple zoom changes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.zoomChanged = false
            }
        }
    }
    @Published var pixelsPerBeat: Double = 30.0 // Base pixels per beat
    @Published var gridOpacity: Double = 0.7 // Grid opacity
    @Published var zoomChanged: Bool = false // Flag to indicate zoom level has changed
    
    // Selection state
    @Published var selectionActive: Bool = false
    @Published var selectionStartBeat: Double = 0.0
    @Published var selectionEndBeat: Double = 0.0
    @Published var selectionTrackId: UUID? = nil
    
    // Computed properties based on zoom level
    var effectivePixelsPerBeat: Double {
        return pixelsPerBeat * zoomLevel
    }
    
    // Determine what divisions to show based on zoom level
    var showSixteenthNotes: Bool {
        return zoomLevel > 0.7
    }
    
    var showEighthNotes: Bool {
        return zoomLevel > 0.4
    }
    
    var showQuarterNotes: Bool {
        // Only show quarter notes (beats) when zoom level is above 0.2
        // This means when zoomed out all the way, only bar lines will be shown
        return zoomLevel > 0.2
    }
    
    // Determine which bar numbers to show based on zoom level
    var barNumberInterval: Int {
        if zoomLevel < 0.2 {
            // When zoomed out all the way, show every 8th bar number (1, 9, 17, 25, etc.)
            return 8
        } else if zoomLevel < 0.4 {
            // When mid-way zoomed out, show every 4th bar number (1, 5, 9, 13, etc.)
            return 4
        } else if zoomLevel < 0.7 {
            // When slightly zoomed out, show every 2nd bar number (1, 3, 5, 7, etc.)
            return 2
        } else {
            // When zoomed in, show every bar number
            return 1
        }
    }
    
    // Check if a specific bar number should be displayed
    func shouldShowBarNumber(for barIndex: Int) -> Bool {
        // Always show the first bar (index 0, which is bar 1)
        if barIndex == 0 {
            return true
        }
        
        // When zoomed in far enough, always show all bar numbers
        if zoomLevel >= 0.7 {
            return true
        }
        
        // For other bars, check if they match the interval pattern
        return (barIndex + 1) % barNumberInterval == 1
    }
    
    // Calculate the width of the timeline content based on zoom level and project settings
    func calculateContentWidth(viewWidth: CGFloat, timeSignatureBeats: Int) -> CGFloat {
        // Ensure the content is at least as wide as the view
        let minWidth = viewWidth
        
        // Calculate width based on number of beats and zoom level
        // We'll show at least 100 bars
        let beatsToShow = 100 * timeSignatureBeats
        let contentWidth = CGFloat(beatsToShow) * effectivePixelsPerBeat
        
        return max(minWidth, contentWidth)
    }
    
    // Start a new selection
    func startSelection(at beat: Double, trackId: UUID) {
        selectionStartBeat = beat
        selectionEndBeat = beat
        selectionTrackId = trackId
        selectionActive = true
    }
    
    // Update the end point of the selection
    func updateSelection(to beat: Double) {
        selectionEndBeat = beat
    }
    
    // Clear the current selection
    func clearSelection() {
        selectionActive = false
        selectionStartBeat = 0.0
        selectionEndBeat = 0.0
        selectionTrackId = nil
    }
    
    // Get the normalized selection range (start always less than end)
    var normalizedSelectionRange: (start: Double, end: Double) {
        if selectionStartBeat <= selectionEndBeat {
            return (selectionStartBeat, selectionEndBeat)
        } else {
            return (selectionEndBeat, selectionStartBeat)
        }
    }
    
    // Check if a track has an active selection
    func hasSelection(trackId: UUID) -> Bool {
        return selectionActive && selectionTrackId == trackId
    }
} 