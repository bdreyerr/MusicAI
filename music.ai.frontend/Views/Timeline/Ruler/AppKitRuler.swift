import SwiftUI
import AppKit

/// SwiftUI wrapper for the AppKit-based ruler
struct AppKitRuler: NSViewRepresentable {
    @ObservedObject var state: TimelineStateViewModel
    @ObservedObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    // Dimensions
    var width: CGFloat
    var height: CGFloat
    
    // Create the NSView with appropriate configuration
    func makeNSView(context: Context) -> TimelineRulerView {
        let rulerView = TimelineRulerView(
            frame: NSRect(x: 0, y: 0, width: width, height: height)
        )
        
        // Configure the ruler view with our state
        rulerView.configure(
            state: state,
            projectViewModel: projectViewModel, 
            themeManager: themeManager
        )
        
        return rulerView
    }
    
    // Update the view when SwiftUI state changes
    func updateNSView(_ nsView: TimelineRulerView, context: Context) {
        // Update the view's frame if dimensions have changed
        if nsView.frame.width != width || nsView.frame.height != height {
            nsView.frame = NSRect(x: 0, y: 0, width: width, height: height)
        }
        
        // Notify the view of state changes
        nsView.handleStateUpdates(
            state: state,
            projectViewModel: projectViewModel,
            themeManager: themeManager
        )
    }
}

/// AppKit implementation of the timeline ruler
class TimelineRulerView: NSView {
    // State management
    private var state: TimelineStateViewModel?
    private var projectViewModel: ProjectViewModel?
    private var themeManager: ThemeManager?
    
    // Cache for colors from theme manager
    private var barLineColor: NSColor = .black.withAlphaComponent(0.6)
    private var halfBarLineColor: NSColor = .black.withAlphaComponent(0.5)
    private var quarterBarLineColor: NSColor = .black.withAlphaComponent(0.5)
    private var eighthBarLineColor: NSColor = .black.withAlphaComponent(0.5)
    private var sixteenthBarLineColor: NSColor = .black.withAlphaComponent(0.5)
    private var textColor: NSColor = .black
    
    // Cached data for rendering
    private var zoomLevel: Int = 0
    private var pixelsPerBeat: Double = 30.0
    private var timeSignatureBeats: Int = 4
    private var totalBars: Int = 81
    
    // Last known scroll position
    private var scrollOffset: CGPoint = .zero
    private var lastViewportWidth: CGFloat = 0
    
    // Cached rendering layers
    private var backgroundLayer: CALayer?
    private var gridLayer: CATiledLayer?
    
    // Debug flag
    private var debugMode: Bool = false
    
    // Display link for smooth scrolling
    private var displayLink: CVDisplayLink?
    
    // Line heights for different markers - relative to the view height
    private let barLineHeight: CGFloat = 0.4
    private let halfBarLineHeight: CGFloat = 0.3
    private let quarterLineHeight: CGFloat = 0.2
    private let eighthLineHeight: CGFloat = 0.15
    private let sixteenthLineHeight: CGFloat = 0.1
    
    // Constants
    private let tileSizePoints: CGFloat = 256
    private let textLabelHeight: CGFloat = 14
    
    // Initialize with default frame
    override init(frame: NSRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        // Enable layer-backing for the view
        self.wantsLayer = true
        self.layer = CALayer()
        self.layer?.backgroundColor = NSColor.clear.cgColor
        
        // Create the background layer
        backgroundLayer = CALayer()
        backgroundLayer?.backgroundColor = NSColor.clear.cgColor
        
        // Create the grid layer for tiled rendering
        let tileLayer = CATiledLayer()
        tileLayer.tileSize = CGSize(width: tileSizePoints, height: bounds.height)
        tileLayer.levelsOfDetail = 1
        tileLayer.levelsOfDetailBias = 0
        tileLayer.delegate = self
        tileLayer.needsDisplayOnBoundsChange = false
        // Prevent masking of sublayers that might clip text
        tileLayer.masksToBounds = false
        gridLayer = tileLayer
        
        // Add layers in the correct order
        if let layer = self.layer, let bgLayer = backgroundLayer, let gLayer = gridLayer {
            layer.addSublayer(bgLayer)
            layer.addSublayer(gLayer)
            // Ensure parent layer doesn't clip content
            layer.masksToBounds = false
        }
        
        // Setup hover tracking
        setupTrackingArea()
        
        // Setup the display link for smooth scrolling
        setupDisplayLink()
    }
    
    // Configure the view with state objects
    func configure(state: TimelineStateViewModel, projectViewModel: ProjectViewModel, themeManager: ThemeManager) {
        self.state = state
        self.projectViewModel = projectViewModel
        self.themeManager = themeManager
        
        // Cache initial values
        updateCachedValues()
        
        // Update the colors from theme manager
        updateColors()
        
        // Force layout update
        needsLayout = true
    }
    
    // Handle state updates from SwiftUI
    func handleStateUpdates(state: TimelineStateViewModel, projectViewModel: ProjectViewModel, themeManager: ThemeManager) {
        // Check if we need to refresh cached values
        let needsRefresh = self.zoomLevel != state.zoomLevel ||
                          self.pixelsPerBeat != state.effectivePixelsPerBeat ||
                          self.timeSignatureBeats != projectViewModel.timeSignatureBeats ||
                          self.totalBars != state.totalBars
        
        // Check if scroll position has changed
        let scrollChanged = self.scrollOffset != state.scrollOffset ||
                           self.lastViewportWidth != bounds.width
        
        // Check if theme has changed by comparing themeChangeIdentifier
        let themeChanged = self.themeManager?.themeChangeIdentifier != themeManager.themeChangeIdentifier
        
        // Update references
        self.state = state
        self.projectViewModel = projectViewModel
        self.themeManager = themeManager
        
        // Update cached values if needed
        if needsRefresh {
            updateCachedValues()
            resetLayersForRedraw()
        }
        
        // Update colors if theme has changed
        if themeChanged {
            updateColors()
        }
        
        // Update scroll position
        if scrollChanged {
            updateScrollPosition()
        }
    }
    
    // Cache values from view models
    private func updateCachedValues() {
        guard let state = state, let projectViewModel = projectViewModel else { return }
        
        zoomLevel = state.zoomLevel
        pixelsPerBeat = state.effectivePixelsPerBeat
        timeSignatureBeats = projectViewModel.timeSignatureBeats
        totalBars = state.totalBars
        scrollOffset = state.scrollOffset
        lastViewportWidth = bounds.width
    }
    
    // Update colors from theme manager
    private func updateColors() {
        guard let themeManager = themeManager else { return }
        
        // Set the background color for the main view
        self.layer?.backgroundColor = NSColor(themeManager.rulerBackgroundColor).cgColor
        backgroundLayer?.backgroundColor = NSColor(themeManager.rulerBackgroundColor).cgColor
        
        // Convert SwiftUI colors to NSColors for grid lines with better contrast in light themes
        let isDarkTheme = themeManager.isDarkMode
        
        // Use appropriate opacity for light themes - lighter than before
        barLineColor = isDarkTheme ? 
            NSColor(themeManager.gridLineColor.opacity(0.9)) :
            NSColor.black.withAlphaComponent(0.6)
            
        halfBarLineColor = isDarkTheme ?
            NSColor(themeManager.gridColor.opacity(0.8)) :
            NSColor.black.withAlphaComponent(0.5)
            
        quarterBarLineColor = isDarkTheme ?
            NSColor(themeManager.gridColor.opacity(0.7)) :
            NSColor.black.withAlphaComponent(0.4)
            
        eighthBarLineColor = isDarkTheme ?
            NSColor(themeManager.secondaryGridColor.opacity(0.6)) :
            NSColor.black.withAlphaComponent(0.3)
            
        sixteenthBarLineColor = isDarkTheme ?
            NSColor(themeManager.tertiaryGridColor.opacity(0.5)) :
            NSColor.black.withAlphaComponent(0.2)
        
        // Ensure text is always high contrast against background
        textColor = isDarkTheme ? 
            NSColor(themeManager.primaryTextColor) :
            NSColor.black.withAlphaComponent(0.9)
        
        // Force redraw when colors change
        needsDisplay = true
        gridLayer?.setNeedsDisplay()
    }
    
    // Reset layers when we need a complete redraw
    private func resetLayersForRedraw() {
        gridLayer?.setNeedsDisplay()
    }
    
    // Update scroll position
    private func updateScrollPosition() {
        guard let state = state else { return }
        
        scrollOffset = state.scrollOffset
        lastViewportWidth = bounds.width
        
        // Update the layer positions for scrolling
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        // Adjust the position of the grid layer to create scrolling effect
        let xOffset = -scrollOffset.x
        gridLayer?.position = CGPoint(x: xOffset, y: 0)
        
        CATransaction.commit()
    }
    
    // MARK: - Drawing Functions
    
    // Draw a vertical line
    private func drawLine(in ctx: CGContext, at x: CGFloat, height: CGFloat, color: NSColor, lineWidth: CGFloat = 1.0) {
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(lineWidth)
        ctx.beginPath()
        // Start from the top of the view and draw downward
        ctx.move(to: CGPoint(x: x, y: 0))
        ctx.addLine(to: CGPoint(x: x, y: height))
        ctx.strokePath()
    }
    
    // Draw text with background
    private func drawText(_ text: String, at x: CGFloat, in ctx: CGContext) {
        // Add pixel padding to ensure numbers aren't clipped at tile boundaries
        let sidePadding: CGFloat = 10 // Extra padding on sides to prevent clipping
        let width: CGFloat = 30 // Much wider to accommodate all numbers safely
        
        // Position rectangle slightly to the right of bar line, centered vertically
        let rect = CGRect(x: x - sidePadding, y: 2, width: width, height: 14)
        
        // Use a different approach to draw text - directly using NSString
        let nsString = text as NSString
        let font = NSFont.systemFont(ofSize: 9, weight: .medium) // Slightly larger font
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor
        ]
        
        // Save the current graphics state
        NSGraphicsContext.saveGraphicsState()
        
        // Create an NSGraphicsContext from our CGContext
        let nsContext = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.current = nsContext
        
        // Calculate text size for proper horizontal centering
        let textSize = nsString.size(withAttributes: attributes)
        
        // Simple centered position in the rectangle
        let centerX = rect.midX - (textSize.width / 2)
        let centerY = rect.midY - (textSize.height / 2)
        
        // Draw the text at the calculated position
        nsString.draw(at: NSPoint(x: centerX, y: centerY), withAttributes: attributes)
        
        // Restore the previous graphics context
        NSGraphicsContext.restoreGraphicsState()
    }
        
    private func drawGridInRect(_ ctx: CGContext, rect: CGRect) {
        // Calculate which bars are visible in this tile
        let beatsPerBar = Double(timeSignatureBeats)
        let pixelsPerBar = pixelsPerBeat * beatsPerBar
        
        // Determine the range of bars visible in this rect
        let startBarFloat = Double(rect.minX) / pixelsPerBar
        let endBarFloat = Double(rect.maxX) / pixelsPerBar
        
        let startBar = max(0, Int(floor(startBarFloat)))
        let endBar = min(totalBars, Int(ceil(endBarFloat)) + 1)
        
        // Draw the appropriate grid based on zoom level
        switch zoomLevel {
        case 0:
            drawZoomLevel0Grid(ctx, rect: rect, startBar: startBar, endBar: endBar)
        case 1:
            drawZoomLevel1Grid(ctx, rect: rect, startBar: startBar, endBar: endBar)
        case 2, 3:
            drawZoomLevel2Or3Grid(ctx, rect: rect, startBar: startBar, endBar: endBar)
        case 4, 5:
            drawZoomLevel4Or5Grid(ctx, rect: rect, startBar: startBar, endBar: endBar)
        case 6:
            drawZoomLevel6Grid(ctx, rect: rect, startBar: startBar, endBar: endBar)
        default:
            drawZoomLevel3Grid(ctx, rect: rect, startBar: startBar, endBar: endBar)
        }
    }
    
    // MARK: - Grid Drawing by Zoom Level
    
    // Zoom Level 0 (closest zoom)
    private func drawZoomLevel0Grid(_ ctx: CGContext, rect: CGRect, startBar: Int, endBar: Int) {
        let beatsPerBar = Double(timeSignatureBeats)
        let pixelsPerBar = pixelsPerBeat * beatsPerBar
        
        for barIndex in startBar..<endBar {
            for beat in 0..<Int(beatsPerBar) {
                let beatPosition = Double(barIndex) * beatsPerBar + Double(beat)
                let x = CGFloat(beatPosition * pixelsPerBeat)
                
                // Skip if outside visible rect
                if x < rect.minX || x > rect.maxX {
                    continue
                }
                
                // Draw quarter note line (beat line)
                let isBarLine = beat == 0
                let lineHeight = isBarLine ?
                    bounds.height * barLineHeight :
                    bounds.height * quarterLineHeight
                
                drawLine(
                    in: ctx, at: x, height: lineHeight,
                    color: isBarLine ? barLineColor : quarterBarLineColor,
                    lineWidth: isBarLine ? 1.2 : 0.8
                )
                
                // Draw text for bar numbers
                if isBarLine {
                    let barNum = barIndex + 1
                    drawText("\(barNum)", at: x, in: ctx)
                }
                
                // Draw eighth notes between beats
                if beat < Int(beatsPerBar) {
                    let eighthPosition = beatPosition + 0.5
                    let eighthX = CGFloat(eighthPosition * pixelsPerBeat)
                    
                    // Skip if outside visible rect
                    if eighthX >= rect.minX && eighthX <= rect.maxX {
                        drawLine(
                            in: ctx, at: eighthX, height: bounds.height * eighthLineHeight,
                            color: eighthBarLineColor, lineWidth: 0.7
                        )
                    }
                }
            }
        }
        
        // Draw the line for the very last bar if needed
        let lastBarPosition = Double(endBar) * beatsPerBar
        let lastBarX = CGFloat(lastBarPosition * pixelsPerBeat)
        
        if lastBarX >= rect.minX && lastBarX <= rect.maxX {
            drawLine(
                in: ctx, at: lastBarX, height: bounds.height * barLineHeight,
                color: barLineColor, lineWidth: 1.2
            )
            
            // Draw text for the last bar
            let barNum = endBar + 1
            drawText("\(barNum)", at: lastBarX, in: ctx)
        }
    }
    
    // Zoom Level 1
    private func drawZoomLevel1Grid(_ ctx: CGContext, rect: CGRect, startBar: Int, endBar: Int) {
        let beatsPerBar = Double(timeSignatureBeats)
        let pixelsPerBar = pixelsPerBeat * beatsPerBar
        
        for barIndex in startBar..<endBar {
            let barPosition = Double(barIndex) * beatsPerBar
            let x = CGFloat(barPosition * pixelsPerBeat)
            
            // Skip if outside visible rect
            if x < rect.minX || x > rect.maxX {
                continue
            }
            
            // Draw bar line
            drawLine(
                in: ctx, at: x, height: bounds.height * barLineHeight,
                color: barLineColor, lineWidth: 1.2
            )
            
            // Draw text for bar numbers
            let barNum = barIndex + 1
            drawText("\(barNum)", at: x, in: ctx)
            
            // Draw quarter/half bar markers
            for beatOffset in [0.25, 0.5, 0.75] {
                let beatPosition = barPosition + beatOffset * beatsPerBar
                let markerX = CGFloat(beatPosition * pixelsPerBeat)
                
                // Skip if outside visible rect
                if markerX < rect.minX || markerX > rect.maxX {
                    continue
                }
                
                let lineHeight = beatOffset == 0.5 ?
                    bounds.height * halfBarLineHeight :
                    bounds.height * quarterLineHeight
                let lineColor = beatOffset == 0.5 ? halfBarLineColor : quarterBarLineColor
                
                drawLine(
                    in: ctx, at: markerX, height: lineHeight,
                    color: lineColor, lineWidth: beatOffset == 0.5 ? 0.9 : 0.7
                )
            }
        }
        
        // Draw the line for the very last bar if needed
        let lastBarPosition = Double(endBar) * beatsPerBar
        let lastBarX = CGFloat(lastBarPosition * pixelsPerBeat)
        
        if lastBarX >= rect.minX && lastBarX <= rect.maxX {
            drawLine(
                in: ctx, at: lastBarX, height: bounds.height * barLineHeight,
                color: barLineColor, lineWidth: 1.2
            )
            
            // Draw text for the last bar
            let barNum = endBar + 1
            drawText("\(barNum)", at: lastBarX, in: ctx)
        }
    }
    
    // Zoom Level 2 or 3
    private func drawZoomLevel2Or3Grid(_ ctx: CGContext, rect: CGRect, startBar: Int, endBar: Int) {
        let beatsPerBar = Double(timeSignatureBeats)
        let pixelsPerBar = pixelsPerBeat * beatsPerBar
        
        for barIndex in startBar..<endBar {
            let barPosition = Double(barIndex) * beatsPerBar
            let x = CGFloat(barPosition * pixelsPerBeat)
            
            // Skip if outside visible rect
            if x < rect.minX || x > rect.maxX {
                continue
            }
            
            // Draw bar line
            drawLine(
                in: ctx, at: x, height: bounds.height * barLineHeight,
                color: barLineColor, lineWidth: 1.2
            )
            
            // Draw text for bar numbers
            let barNum = barIndex + 1
            drawText("\(barNum)", at: x, in: ctx)
            
            // Draw half-bar marker
            let halfBarPosition = barPosition + beatsPerBar / 2
            let halfBarX = CGFloat(halfBarPosition * pixelsPerBeat)
            
            if halfBarX >= rect.minX && halfBarX <= rect.maxX {
                drawLine(
                    in: ctx, at: halfBarX, height: bounds.height * halfBarLineHeight,
                    color: halfBarLineColor, lineWidth: 0.9
                )
            }
        }
        
        // Draw the line for the very last bar if needed
        let lastBarPosition = Double(endBar) * beatsPerBar
        let lastBarX = CGFloat(lastBarPosition * pixelsPerBeat)
        
        if lastBarX >= rect.minX && lastBarX <= rect.maxX {
            drawLine(
                in: ctx, at: lastBarX, height: bounds.height * barLineHeight,
                color: barLineColor, lineWidth: 1.2
            )
            
            // Draw text for the last bar
            let barNum = endBar + 1
            drawText("\(barNum)", at: lastBarX, in: ctx)
        }
    }
    
    // Zoom Level 3 (extracted for reuse)
    private func drawZoomLevel3Grid(_ ctx: CGContext, rect: CGRect, startBar: Int, endBar: Int) {
        drawZoomLevel2Or3Grid(ctx, rect: rect, startBar: startBar, endBar: endBar)
    }
    
    // Zoom Level 4 or 5
    private func drawZoomLevel4Or5Grid(_ ctx: CGContext, rect: CGRect, startBar: Int, endBar: Int) {
        let beatsPerBar = Double(timeSignatureBeats)
        let pixelsPerBar = pixelsPerBeat * beatsPerBar
        
        for barIndex in startBar..<endBar {
            let barPosition = Double(barIndex) * beatsPerBar
            let x = CGFloat(barPosition * pixelsPerBeat)
            
            // Skip if outside visible rect
            if x < rect.minX || x > rect.maxX {
                continue
            }
            
            // Draw bar line
            drawLine(
                in: ctx, at: x, height: bounds.height * barLineHeight,
                color: barLineColor, lineWidth: 1.2
            )
            
            // For zoom level 5, only draw text for even-numbered bars
            if zoomLevel < 5 || barIndex % 2 == 0 {
                // Draw text for bar numbers
                let barNum = barIndex + 1
                drawText("\(barNum)", at: x, in: ctx)
            }
        }
        
        // Draw the line for the very last bar if needed
        let lastBarPosition = Double(endBar) * beatsPerBar
        let lastBarX = CGFloat(lastBarPosition * pixelsPerBeat)
        
        if lastBarX >= rect.minX && lastBarX <= rect.maxX {
            drawLine(
                in: ctx, at: lastBarX, height: bounds.height * barLineHeight,
                color: barLineColor, lineWidth: 1.2
            )
            
            // Draw text for the last bar (if it would be shown)
            if zoomLevel < 5 || endBar % 2 == 0 {
                let barNum = endBar + 1
                drawText("\(barNum)", at: lastBarX, in: ctx)
            }
        }
    }
    
    // Zoom Level 6 (furthest zoom)
    private func drawZoomLevel6Grid(_ ctx: CGContext, rect: CGRect, startBar: Int, endBar: Int) {
        let beatsPerBar = Double(timeSignatureBeats)
        let pixelsPerBar = pixelsPerBeat * beatsPerBar
        
        for barIndex in startBar..<endBar {
            let barPosition = Double(barIndex) * beatsPerBar
            let x = CGFloat(barPosition * pixelsPerBeat)
            
            // Skip if outside visible rect
            if x < rect.minX || x > rect.maxX {
                continue
            }
            
            // Draw bar line
            drawLine(
                in: ctx, at: x, height: bounds.height * barLineHeight,
                color: barLineColor, lineWidth: 1.2
            )
            
            // Only draw text for every 4 bars at zoom level 6
            if barIndex % 4 == 0 {
                // Draw text for bar numbers
                let barNum = barIndex + 1
                drawText("\(barNum)", at: x, in: ctx)
            }
        }
        
        // Draw the line for the very last bar if needed
        let lastBarPosition = Double(endBar) * beatsPerBar
        let lastBarX = CGFloat(lastBarPosition * pixelsPerBeat)
        
        if lastBarX >= rect.minX && lastBarX <= rect.maxX {
            drawLine(
                in: ctx, at: lastBarX, height: bounds.height * barLineHeight,
                color: barLineColor, lineWidth: 1.2
            )
            
            // Draw text for the last bar (if it would be shown)
            if endBar % 4 == 0 {
                let barNum = endBar + 1
                drawText("\(barNum)", at: lastBarX, in: ctx)
            }
        }
    }
    
    // Setup tracking area for hover effects
    private func setupTrackingArea() {
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .mouseMoved, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }
    
    // Setup display link for smoother scrolling
    private func setupDisplayLink() {
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        
        if let displayLink = displayLink {
            CVDisplayLinkSetOutputHandler(displayLink) { [weak self] _, _, _, _, _ -> CVReturn in
                DispatchQueue.main.async {
                    self?.updateScrollPositionIfNeeded()
                }
                return kCVReturnSuccess
            }
            CVDisplayLinkStart(displayLink)
        }
    }
    
    // Update scroll position if it has changed
    private func updateScrollPositionIfNeeded() {
        guard let state = state else { return }
        
        if scrollOffset != state.scrollOffset || lastViewportWidth != bounds.width {
            updateScrollPosition()
        }
    }
    
    // MARK: - Layout
    
    override func layout() {
        super.layout()
        
        let totalWidth = getTotalWidth()
        
        // Update layer frames
        backgroundLayer?.frame = bounds
        gridLayer?.frame = CGRect(x: 0, y: 0, width: totalWidth, height: bounds.height)
        
        // Update tracking area
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        setupTrackingArea()
        
        // Update cached viewport width
        lastViewportWidth = bounds.width
    }
    
    // Calculate the total width required
    private func getTotalWidth() -> CGFloat {
        let beatsPerBar = Double(timeSignatureBeats)
        let pixelsPerBar = pixelsPerBeat * beatsPerBar
        return CGFloat(totalBars + 1) * CGFloat(pixelsPerBar)
    }
    
    // Cleanup when view is removed
    deinit {
        if let displayLink = displayLink {
            CVDisplayLinkStop(displayLink)
        }
    }
    
    // MARK: - Mouse Events
    
    override func mouseEntered(with event: NSEvent) {
        // Notify state of hover
        updateStateWithHover(true)
    }
    
    override func mouseExited(with event: NSEvent) {
        // Notify state of hover end
        updateStateWithHover(false)
    }
    
    private func updateStateWithHover(_ isHovering: Bool) {
        // This would communicate with the SwiftUI state if needed
        // For now, we handle hover effects directly in this view
    }
    
    // Override to ensure the view doesn't clip its content
    override var wantsDefaultClipping: Bool {
        return false
    }
    
    // Make sure our layer isn't clipping content during updates
    override func updateLayer() {
        super.updateLayer()
        // Ensure our layer and its sublayers don't clip content
        self.layer?.masksToBounds = false
        gridLayer?.masksToBounds = false
    }
}

// MARK: - CALayerDelegate for Tiled Layer

extension TimelineRulerView: CALayerDelegate {
    func draw(_ layer: CALayer, in ctx: CGContext) {
        // Skip if not our grid layer
        guard layer == gridLayer else { return }
        
        // Get the visible rect that needs to be drawn
        let bounds = ctx.boundingBoxOfClipPath
        drawGridInRect(ctx, rect: bounds)
    }
} 
