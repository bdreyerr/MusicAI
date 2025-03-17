import SwiftUI
import Combine

/// TimelineState manages the visual representation and zoom behavior of the timeline.
/// This is separate from ProjectViewModel which manages the actual music project data.
class TimelineStateViewModel: ObservableObject {
    @Published var zoomLevel: Double = 0.4 { // Increased default zoom level for better initial view
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
    
    // Scroll position
    @Published var scrollOffset: CGPoint = .zero {
        didSet {
            // If the scroll position changed significantly, mark as scrolling
            if abs(oldValue.x - scrollOffset.x) > 0.5 || abs(oldValue.y - scrollOffset.y) > 0.5 {
                isScrolling = true
                
                // Reset the scrolling flag after a very short delay
                cancelScrollingReset()
                scrollingResetWorkItem = DispatchWorkItem {
                    self.isScrolling = false
                    self.scrollingResetWorkItem = nil
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.03, execute: scrollingResetWorkItem!)
            }
        }
    }
    
    // Scrolling state
    @Published var isScrolling: Bool = false
    private var scrollingResetWorkItem: DispatchWorkItem?
    
    // Selection state
    @Published var selectionActive: Bool = false
    @Published var selectionStartBeat: Double = 0.0
    @Published var selectionEndBeat: Double = 0.0
    @Published var selectionTrackId: UUID? = nil
    
    // Minimum number of bars to show when there's no content
    private let minimumBarsToShow: Int = 16
    
    // Padding in bars to add after the last content
    private let contentPaddingBars: Int = 4
    
    // Cancel any pending scrolling reset
    private func cancelScrollingReset() {
        scrollingResetWorkItem?.cancel()
        scrollingResetWorkItem = nil
    }
    
    // Computed properties based on zoom level
    var effectivePixelsPerBeat: Double {
        return pixelsPerBeat * zoomLevel
    }
    
    // Determine what divisions to show based on zoom level
    var showSixteenthNotes: Bool {
        return zoomLevel > 0.7
    }
    
    var showEighthNotes: Bool {
        return zoomLevel > 0.45 && zoomLevel <= 0.7
    }
    
    var showQuarterNotes: Bool {
        return zoomLevel > 0.25 && zoomLevel <= 0.45
    }
    
    // Property for half notes (between quarter notes and bars)
    var showHalfNotes: Bool {
        return zoomLevel > 0.15 && zoomLevel <= 0.25
    }
    
    // Determine which bar numbers to show based on zoom level
    var barNumberInterval: Int {
        if zoomLevel < 0.15 {
            // When zoomed out all the way, show every 2nd bar number
            return 2
        } else if zoomLevel < 0.25 {
            // When mid-way zoomed out, show every 4th bar number (1, 5, 9, 13, etc.)
            return 4
        } else if zoomLevel < 0.45 {
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
        if zoomLevel >= 0.45 {
            return true
        }
        
        // For other bars, check if they match the interval pattern
        return (barIndex + 1) % barNumberInterval == 1
    }
    
    // Calculate the width of the timeline content based on zoom level, project settings, and content
    func calculateContentWidth(viewWidth: CGFloat, timeSignatureBeats: Int, tracks: [Track]? = nil) -> CGFloat {
        // Ensure the content is at least as wide as the view
        let minWidth = viewWidth
        
        // Calculate the furthest beat position based on content
        var furthestBeat: Double = 0
        
        if let tracks = tracks {
            // Find the furthest end position of any clip in any track
            for track in tracks {
                // Check MIDI clips
                for clip in track.midiClips {
                    let clipEndBeat = clip.startBeat + clip.duration
                    furthestBeat = max(furthestBeat, clipEndBeat)
                }
                
                // Check audio clips
                for clip in track.audioClips {
                    let clipEndBeat = clip.startBeat + clip.duration
                    furthestBeat = max(furthestBeat, clipEndBeat)
                }
            }
        }
        
        // If there's no content, show a minimum number of bars
        // Otherwise, add padding after the last content
        let beatsToShow: Double
        if furthestBeat > 0 {
            // Convert furthest beat to bars, round up, and add padding
            let furthestBar = ceil(furthestBeat / Double(timeSignatureBeats))
            let barsToShow = Int(furthestBar) + contentPaddingBars
            beatsToShow = Double(barsToShow * timeSignatureBeats)
        } else {
            // Show minimum number of bars when there's no content
            beatsToShow = Double(minimumBarsToShow * timeSignatureBeats)
        }
        
        // Calculate width based on beats to show and zoom level
        let contentWidth = CGFloat(beatsToShow) * CGFloat(effectivePixelsPerBeat)
        
        return max(minWidth, contentWidth)
    }
    
    // Start a new selection
    func startSelection(at beat: Double, trackId: UUID) {
        selectionStartBeat = beat
        selectionEndBeat = beat
        selectionTrackId = trackId
        selectionActive = true
        // print("🔍 SELECTION: Started selection at beat \(beat) on track \(trackId)")
    }
    
    // Update the end point of the selection
    func updateSelection(to beat: Double) {
        selectionEndBeat = beat
        // print("🔍 SELECTION: Updated selection to beat \(beat), range: \(selectionStartBeat) to \(selectionEndBeat)")
    }
    
    // Clear the current selection
    func clearSelection() {
        // if selectionActive {
        //     print("🔍 SELECTION: Cleared selection")
        // }
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
        let result = selectionActive && selectionTrackId == trackId
        // if selectionActive {
        //     print("🔍 SELECTION: Track \(trackId) has selection: \(result), active track: \(String(describing: selectionTrackId))")
        // }
        return result
    }
    
    // Clean up when the view model is deallocated
    deinit {
        cancelScrollingReset()
    }
} 
