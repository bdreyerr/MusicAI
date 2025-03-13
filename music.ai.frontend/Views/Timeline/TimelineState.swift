import SwiftUI
import Combine

/// TimelineState manages the visual representation and zoom behavior of the timeline.
/// This is separate from ProjectViewModel which manages the actual music project data.
class TimelineState: ObservableObject {
    @Published var zoomLevel: Double = 0.146 // Default zoom level to match the old implementation
    @Published var pixelsPerBeat: Double = 30.0 // Base pixels per beat
    @Published var gridOpacity: Double = 0.7 // Grid opacity
    
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
        return true // Always show quarter notes (beats)
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
} 