import SwiftUI
import Combine

/// TimelineState manages the visual representation and zoom behavior of the timeline.
/// This is separate from ProjectViewModel which manages the actual music project data.
class TimelineStateViewModel: ObservableObject {
    @Published var zoomLevel: Int = 3 { // Default to middle zoom level
        didSet {
            // Ensure zoom level is within bounds
            if zoomLevel < 0 {
                zoomLevel = 0
            } else if zoomLevel > 6 {
                zoomLevel = 6
            }
            
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
    @Published var contentSizeChangeId: UUID = UUID() // ID that changes when content size changes
    
    // Scroll position
    @Published var scrollOffset: CGPoint = .zero {
        didSet {
            // If the scroll position changed significantly, mark as scrolling
            if abs(oldValue.x - scrollOffset.x) > 0.5 || abs(oldValue.y - scrollOffset.y) > 0.5 {
                // Calculate values outside of the async block
                let currentTime = Date()
                let timeDelta = currentTime.timeIntervalSince(lastScrollTime)
                let horizontalDistance = abs(scrollOffset.x - lastScrollPosition.x)
                let verticalDistance = abs(scrollOffset.y - lastScrollPosition.y)
                let shouldCalculateSpeed = timeDelta > 0 && horizontalDistance > verticalDistance
                
                // Immediately update tracking variables (not published properties)
                lastScrollPosition = scrollOffset
                lastScrollTime = currentTime
                
                // Use DispatchQueue.main.async to batch our state updates
                DispatchQueue.main.async {
                    self.isScrolling = true
                    
                    // Calculate scrolling speed if we have valid data
                    if shouldCalculateSpeed {
                        // Calculate pixels per second (mainly focusing on horizontal)
                        // Use exponential moving average to smooth the speed
                        let newSpeed = horizontalDistance / CGFloat(timeDelta)
                        self.scrollingSpeed = self.scrollingSpeed * 0.7 + newSpeed * 0.3
                    }
                    
                    // Reset the scrolling flag after a very short delay
                    self.cancelScrollingReset()
                    self.scrollingResetWorkItem = DispatchWorkItem {
                        DispatchQueue.main.async {
                            self.isScrolling = false
                            self.scrollingResetWorkItem = nil
                            
                            // Gradually reset scrolling speed to zero
                            self.resetScrollingSpeed()
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.03, execute: self.scrollingResetWorkItem!)
                }
            }
        }
    }
    
    // Scrolling state tracking
    @Published var isScrolling: Bool = false
    @Published var scrollingSpeed: CGFloat = 0
    
    // Private tracking variables for scrolling
    private var lastScrollPosition: CGPoint = .zero
    private var lastScrollTime: Date = Date()
    private var lastContentOffset: CGFloat = 0
    private var scrollingResetWorkItem: DispatchWorkItem?
    private var scrollingSpeedResetWorkItem: DispatchWorkItem?
    private var scrollTimer: Timer?
    
    // Selection state
    @Published var selectionActive: Bool = false
    @Published var selectionStartBeat: Double = 0.0
    @Published var selectionEndBeat: Double = 0.0
    @Published var selectionTrackId: UUID? = nil
    
    // Fixed 81 bars minimum for the timeline
    private let minimumBarsToShow: Int = 81
    
    // Track the total number of bars in the timeline
    @Published var totalBars: Int = 81
    
    // Number of bars to add when extending the timeline
    let barsToAddIncrement: Int = 16
    
    // Padding in bars to add after the last content
    private let contentPaddingBars: Int = 4
    
    // Base pixels per beat at default zoom level
    private let basePixelsPerBeat: Double = 30.0
    
    // Helper to gradually reset scrolling speed to zero
    func resetScrollingSpeed() {
        // Only proceed if we have a non-zero scrolling speed
        if scrollingSpeed > 0.1 {
            // Reduce speed by 25% every call
            let newSpeed = scrollingSpeed * 0.75
            
            // Use DispatchQueue.main.async to avoid state modification issues
            DispatchQueue.main.async {
                self.scrollingSpeed = newSpeed
            }
            
            // Schedule another reduction after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.resetScrollingSpeed()
            }
        } else {
            // Once speed is very low, just set it to zero
            DispatchQueue.main.async {
                self.scrollingSpeed = 0
            }
        }
    }
    
    // Cancel any pending scrolling reset
    private func cancelScrollingReset() {
        scrollingResetWorkItem?.cancel()
        scrollingResetWorkItem = nil
    }
    
    // Cancel any pending scrolling speed reset
    private func cancelScrollingSpeedReset() {
        scrollingSpeedResetWorkItem?.cancel()
        scrollingSpeedResetWorkItem = nil
    }
    
    // Update scrolling state based on direct scroll offset changes
    // This is used by scroll views to track scrolling performance
    func updateScrollState(offset: CGFloat) {
        // Calculate values outside of the async block
        let currentTime = Date()
        let timeDelta = currentTime.timeIntervalSince(lastScrollTime)
        let offsetDelta = abs(offset - lastContentOffset)
        let hasMovedEnough = offsetDelta > 0.5
        
        // Immediately update tracking variables (not published properties)
        lastContentOffset = offset
        lastScrollTime = currentTime
        
        // Only proceed if we have meaningful movement
        if hasMovedEnough && timeDelta > 0.01 {
            // Calculate the new speed value
            let newSpeed = offsetDelta / CGFloat(timeDelta)
            
            // Use DispatchQueue.main.async to batch our state updates
            DispatchQueue.main.async {
                // Calculate scrolling speed using the stored data
                self.scrollingSpeed = self.scrollingSpeed * 0.5 + newSpeed * 0.5
                
                // Set scrolling state to true
                if !self.isScrolling {
                    self.isScrolling = true
                }
                
                // Reset the timer
                self.scrollTimer?.invalidate()
                
                // Set timer to mark scrolling as ended after a delay
                self.scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { [weak self] _ in
                    DispatchQueue.main.async {
                        self?.isScrolling = false
                        self?.scrollingSpeed = 0
                    }
                }
            }
        }
    }
    
    // Notify that content size has changed (without manipulating zoom level)
    func contentSizeChanged() {
        // Update the ID to force views to redraw
        contentSizeChangeId = UUID()
    }
    
    // Add more bars to the timeline
    func extendTimeline() {
        totalBars += barsToAddIncrement
        contentSizeChanged()
    }
    
    // Computed properties based on zoom level
    var effectivePixelsPerBeat: Double {
        // Scale pixels per beat based on zoom level
        // Zoom level 0 (closest) has the most pixels per beat
        // Zoom level 6 (furthest) has the least pixels per beat
        switch zoomLevel {
        case 0: return basePixelsPerBeat * 4.0    // Closest - eighth notes visible
        case 1: return basePixelsPerBeat * 2.0    // Quarter notes visible
        case 2: return basePixelsPerBeat * 1.5    // Quarter notes visible (slightly less zoomed)
        case 3: return basePixelsPerBeat          // Half bar markers visible
        case 4: return basePixelsPerBeat * 0.6    // Half bar markers visible (less zoomed)
        case 5: return basePixelsPerBeat * 0.3    // Bar markers visible
        case 6: return basePixelsPerBeat * 0.15   // Bar markers visible (furthest out)
        default: return basePixelsPerBeat
        }
    }
    
    // Check if a specific bar number should be displayed
    func shouldShowBarNumber(for barIndex: Int) -> Bool {
        // Always show the first bar (index 0, which is bar 1)
        if barIndex == 0 {
            return true
        }
        
        // For zoom level 0, we show quarter-bar numbers
        if zoomLevel == 0 {
            // Show numbers at every quarter bar (1, 1.2, 1.3, 1.4, 2, etc.)
            return true
        }
        
        // Special handling for zoom levels 4 and 5 to show odd-numbered bars
        if zoomLevel == 4 || zoomLevel == 5 {
            // Show odd-numbered bar numbers only (1, 3, 5, 7...)
            // barIndex is 0-based, so displayed bar number is barIndex + 1
            // We check if this is odd (modulo 2 equals 1)
            return (barIndex + 1) % 2 == 1
        }
        
        // For other zoom levels, check against the interval
        return (barIndex + 1) % rulerNumberInterval == 0
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
        
        // Convert furthest content beat to bars
        let furthestContentBar = (furthestBeat > 0) ? 
            Int(ceil(furthestBeat / Double(timeSignatureBeats))) + contentPaddingBars : 0
        
        // Use the maximum of furthest content, minimum bars required, or current total bars
        let barsToShow = max(max(furthestContentBar, minimumBarsToShow), totalBars)
        
        // Update total bars if content extends beyond current total
        if barsToShow > totalBars {
            totalBars = barsToShow
        }
        
        // Calculate beats based on bars
        let beatsToShow = Double(barsToShow * timeSignatureBeats)
        
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
    
    // MARK: - Timeline Grid Properties
    
    // Return the appropriate grid division based on zoom level
    enum GridDivision {
        case sixteenth         // Show sixteenth note grid lines
        case eighth            // Show eighth note grid lines
        case quarter           // Show quarter note (beat) grid lines
        case half              // Show half note (half-bar) grid lines
        case bar               // Show only bar lines
        case twoBar            // Show two-bar lines
        case fourBar           // Show four-bar lines
    }
    
    var gridDivision: GridDivision {
        switch zoomLevel {
        case 0: return .sixteenth   // Closest zoom - show sixteenth notes
        case 1: return .eighth      // Show eighth notes
        case 2: return .quarter     // Show quarter notes (beats)
        case 3: return .half        // Show half notes (half-bars)
        case 4: return .bar         // Show bar lines
        case 5: return .twoBar      // Show two-bar grid lines
        case 6: return .fourBar     // Furthest zoom - show four-bar grid lines
        default: return .half
        }
    }
    
    // MARK: - Ruler Properties
    
    // Return the appropriate ruler division based on zoom level
    enum RulerDivision {
        case sixteenth         // Show lines at sixteenth notes
        case eighth            // Show lines at eighth notes
        case quarter           // Show lines at quarter notes
        case half              // Show lines at half notes
        case bar               // Show lines at bars
        case twoBar            // Show lines at two bars
        case fourBar           // Show lines at four bars
    }
    
    var rulerDivision: RulerDivision {
        switch zoomLevel {
        case 0: return .sixteenth
        case 1: return .eighth
        case 2: return .quarter
        case 3: return .half
        case 4: return .bar
        case 5: return .twoBar
        case 6: return .fourBar
        default: return .half
        }
    }
    
    // Return the bar interval for displaying numbers on the ruler
    var rulerNumberInterval: Int {
        switch zoomLevel {
        case 0: return 1       // Show numbers for every quarter bar
        case 1, 2, 3: return 1 // Show numbers for every bar
        case 4, 5: return 2    // Show numbers every 2 bars
        case 6: return 4       // Show numbers every 4 bars
        default: return 1
        }
    }
    
    // Return the interval (in bars) for alternating grid colors
    var gridAlternatingInterval: Int {
        switch zoomLevel {
        case 0, 1: return 1    // Alternate colors every bar
        case 2, 3, 4, 5: return 4  // Alternate colors every 4 bars
        case 6: return 16      // Alternate colors every 16 bars
        default: return 4
        }
    }
    
    // Determine what types of dots to show on the ruler
    func rulerDotType(for barPosition: Double) -> String? {
        let beatInBar = barPosition.truncatingRemainder(dividingBy: 1.0)
        
        switch zoomLevel {
        case 0:
            // Eighth bar dots (at 1/8, 3/8, 5/8, 7/8 positions in a beat)
            if [0.125, 0.375, 0.625, 0.875].contains(where: { abs(beatInBar - $0) < 0.001 }) {
                return "eighth"
            }
            return nil
            
        case 1:
            // Quarter bar dots (at 1/4, 1/2, 3/4 positions in a bar)
            if [0.25, 0.5, 0.75].contains(where: { abs(beatInBar - $0) < 0.001 }) {
                return "quarter"
            }
            return nil
            
        case 2, 3:
            // Half bar dots (at 1/2 position in a bar)
            if abs(beatInBar - 0.5) < 0.001 {
                return "half"
            }
            return nil
            
        case 4, 5:
            // One bar dots
            if beatInBar < 0.001 {
                return "bar"
            }
            return nil
            
        case 6:
            // Two bar dots
            if barPosition.truncatingRemainder(dividingBy: 2.0) < 0.001 && 
               barPosition.truncatingRemainder(dividingBy: 4.0) >= 0.001 {
                return "twoBar"
            }
            return nil
            
        default:
            return nil
        }
    }
    
    // MARK: - Zoom Gestures
    
    // Track the last pinch gesture timestamp to prevent too frequent zoom changes
    private var lastPinchGestureTime: Date? = nil
    private let pinchGestureCooldown: TimeInterval = 0.25 // Seconds between allowed zoom changes
    
    // Track the cumulative scale to handle partial zoom changes
    private var cumulativeScale: CGFloat = 1.0
    
    // Handle pinch gestures from trackpad for zooming
    func handlePinchGesture(scale: CGFloat) {
        // Scale factor determines zoom direction
        // scale > 1 means pinch out (zoom in - decrease zoom level)
        // scale < 1 means pinch in (zoom out - increase zoom level)
        
        // Check if we need to enforce cooldown
        let now = Date()
        if let lastTime = lastPinchGestureTime, 
           now.timeIntervalSince(lastTime) < pinchGestureCooldown {
            // Not enough time has passed since the last zoom change
            return
        }
        
        // Set thresholds for pinch gesture to make it more sensitive
        let zoomInThreshold: CGFloat = 1.10  // Require 10% increase to zoom in (was 15%)
        let zoomOutThreshold: CGFloat = 0.90 // Require 10% decrease to zoom out (was 85%)
        
        // Update cumulative scale with this pinch value
        cumulativeScale *= scale
        
        // Check if we've reached a threshold for zooming
        if cumulativeScale >= zoomInThreshold && zoomLevel > 0 {
            // Pinch out - zoom IN (decrease zoom level)
            zoomLevel = max(0, zoomLevel - 1)
            lastPinchGestureTime = now
            // Reset cumulative scale but maintain direction tendency for smoother multi-level zooms
            cumulativeScale = 1.02 // Slightly above 1 to maintain zoom-in direction
        } else if cumulativeScale <= zoomOutThreshold && zoomLevel < 6 {
            // Pinch in - zoom OUT (increase zoom level)
            zoomLevel = min(6, zoomLevel + 1)
            lastPinchGestureTime = now
            // Reset cumulative scale but maintain direction tendency for smoother multi-level zooms
            cumulativeScale = 0.98 // Slightly below 1 to maintain zoom-out direction
        }
        
        // Reset cumulative scale completely when pinch ends
        if scale == 1.0 {
            cumulativeScale = 1.0
        }
    }
    
    // Clean up when the view model is deallocated
    deinit {
        cancelScrollingReset()
        scrollTimer?.invalidate()
    }
} 
