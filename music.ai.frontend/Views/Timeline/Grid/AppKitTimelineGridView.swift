import SwiftUI
import AppKit

/// SwiftUI wrapper for the AppKit-based timeline grid
struct AppKitTimelineGridView: NSViewRepresentable {
    @ObservedObject var state: TimelineStateViewModel
    @ObservedObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    // Dimensions
    var width: CGFloat
    var height: CGFloat
    
    // Create the NSView with appropriate configuration
    func makeNSView(context: Context) -> TimelineGridNSView {
        let gridView = TimelineGridNSView(
            frame: NSRect(x: 0, y: 0, width: width, height: height)
        )
        
        // Configure the grid view with our state
        gridView.configure(
            state: state,
            projectViewModel: projectViewModel, 
            themeManager: themeManager
        )
        
        return gridView
    }
    
    // Update the view when SwiftUI state changes
    func updateNSView(_ nsView: TimelineGridNSView, context: Context) {
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

/// AppKit implementation of the timeline grid
class TimelineGridNSView: NSView {
    // State management
    private var state: TimelineStateViewModel?
    private var projectViewModel: ProjectViewModel?
    private var themeManager: ThemeManager?
    
    // Cache for colors from theme manager
    private var barLineColor: NSColor = .black.withAlphaComponent(0.4)
    private var halfBarLineColor: NSColor = .black.withAlphaComponent(0.8)
    private var quarterBarLineColor: NSColor = .black.withAlphaComponent(0.8)
    private var eighthBarLineColor: NSColor = .black.withAlphaComponent(0.9)
    private var sixteenthBarLineColor: NSColor = .black.withAlphaComponent(0.7)
    private var alternatingBgColor: NSColor = .lightGray.withAlphaComponent(0.1)
    
    // Cached data for rendering
    private var gridDivision: TimelineStateViewModel.GridDivision = .quarter
    private var zoomLevel: Int = 0
    private var pixelsPerBeat: Double = 30.0
    private var timeSignatureBeats: Int = 4
    private var totalBars: Int = 81
    private var gridAlternatingInterval: Int = 4
    
    // Last known scroll position
    private var scrollOffset: CGPoint = .zero
    private var lastViewportWidth: CGFloat = 0
    
    // Cached rendering layers
    private var backgroundLayer: CALayer?
    private var gridLayer: CATiledLayer?
    
    // Display link for smooth scrolling
    private var displayLink: CVDisplayLink?
    
    // Constants
    private let tileSizePoints: CGFloat = 512 // Larger tile size for the grid
    private let viewportMargin: CGFloat = 100 // Extra margin outside viewport
    
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
        
        // Create the background layer for alternating backgrounds
        backgroundLayer = CALayer()
        backgroundLayer?.backgroundColor = NSColor.clear.cgColor
        
        // Create the grid layer for tiled rendering
        let tileLayer = CATiledLayer()
        tileLayer.tileSize = CGSize(width: tileSizePoints, height: bounds.height)
        tileLayer.levelsOfDetail = 1
        tileLayer.levelsOfDetailBias = 0
        tileLayer.delegate = self
        tileLayer.needsDisplayOnBoundsChange = false
        tileLayer.masksToBounds = false
        gridLayer = tileLayer
        
        // Add layers in the correct order
        if let layer = self.layer, let bgLayer = backgroundLayer, let gLayer = gridLayer {
            layer.addSublayer(bgLayer)
            layer.addSublayer(gLayer)
            layer.masksToBounds = false
        }
        
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
        let needsRefresh = self.gridDivision != state.gridDivision ||
                          self.zoomLevel != state.zoomLevel ||
                          self.pixelsPerBeat != state.effectivePixelsPerBeat ||
                          self.timeSignatureBeats != projectViewModel.timeSignatureBeats ||
                          self.totalBars != state.totalBars ||
                          self.gridAlternatingInterval != state.gridAlternatingInterval
        
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
        
        gridDivision = state.gridDivision
        zoomLevel = state.zoomLevel
        pixelsPerBeat = state.effectivePixelsPerBeat
        timeSignatureBeats = projectViewModel.timeSignatureBeats
        totalBars = state.totalBars
        scrollOffset = state.scrollOffset
        lastViewportWidth = bounds.width
        gridAlternatingInterval = state.gridAlternatingInterval
    }
    
    // Update colors from theme manager
    private func updateColors() {
        guard let themeManager = themeManager else { return }
        
        // Set the background layer to clear to allow transparency
        self.layer?.backgroundColor = NSColor.clear.cgColor
        backgroundLayer?.backgroundColor = NSColor.clear.cgColor
        
        // Convert SwiftUI colors to NSColors
        let isDarkTheme = themeManager.isDarkMode
        
        // Grid line colors with appropriate opacity
        barLineColor = NSColor(themeManager.gridLineColor.opacity(0.4))
        halfBarLineColor = NSColor(themeManager.secondaryGridColor.opacity(0.8))
        quarterBarLineColor = NSColor(themeManager.tertiaryGridColor.opacity(0.8))
        eighthBarLineColor = NSColor(themeManager.tertiaryGridColor.opacity(0.9))
        sixteenthBarLineColor = NSColor(themeManager.tertiaryGridColor.opacity(0.7))
        
        // Alternating section background color
        alternatingBgColor = NSColor(themeManager.alternatingGridSectionColor)
        
        // Force redraw when colors change
        needsDisplay = true
        backgroundLayer?.setNeedsDisplay()
        gridLayer?.setNeedsDisplay()
    }
    
    // Reset layers when we need a complete redraw
    private func resetLayersForRedraw() {
        backgroundLayer?.setNeedsDisplay()
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
        
        // Update both background and grid layers
        let xOffset = -scrollOffset.x
        backgroundLayer?.position = CGPoint(x: xOffset, y: 0)
        gridLayer?.position = CGPoint(x: xOffset, y: 0)
        
        CATransaction.commit()
    }
    
    // MARK: - Drawing Functions
    
    // Draw alternating bar backgrounds
    private func drawAlternatingBarBackgrounds(in ctx: CGContext, rect: CGRect) {
        let beatsPerBar = Double(timeSignatureBeats)
        let pixelsPerBar = pixelsPerBeat * beatsPerBar
        
        // Calculate visible bar range
        let startX = rect.minX
        let endX = rect.maxX
        let startBar = Int(floor(startX / CGFloat(pixelsPerBar)))
        let endBar = Int(ceil(endX / CGFloat(pixelsPerBar)))
        
        // Draw alternating backgrounds
        for barIndex in stride(from: startBar - (startBar % gridAlternatingInterval), through: endBar, by: gridAlternatingInterval) {
            // Only color every other group of bars
            if (barIndex / gridAlternatingInterval) % 2 == 0 {
                let barPosition = Double(barIndex) * pixelsPerBar
                let barWidth = Double(gridAlternatingInterval) * pixelsPerBar
                
                let barRect = CGRect(
                    x: barPosition,
                    y: 0,
                    width: barWidth,
                    height: rect.height
                )
                
                // Fill with alternating background color
                ctx.setFillColor(alternatingBgColor.cgColor)
                ctx.fill(barRect)
            }
        }
    }
    
    // Draw a vertical line
    private func drawLine(in ctx: CGContext, at x: CGFloat, height: CGFloat, color: NSColor, lineWidth: CGFloat = 1.0) {
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(lineWidth)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: x, y: 0))
        ctx.addLine(to: CGPoint(x: x, y: height))
        ctx.strokePath()
    }
    
    // MARK: - Grid Drawing Functions
    
    // Draw grid based on zoom level
    private func drawGridInRect(_ ctx: CGContext, rect: CGRect) {
        // First draw the alternating bar backgrounds
        drawAlternatingBarBackgrounds(in: ctx, rect: rect)
        
        // Draw the grid lines based on the current grid division
        switch gridDivision {
        case .sixteenth:
            drawSixteenthNoteGrid(ctx, rect: rect)
        case .eighth:
            drawEighthNoteGrid(ctx, rect: rect)
        case .quarter:
            drawQuarterNoteGrid(ctx, rect: rect)
        case .half:
            drawHalfBarGrid(ctx, rect: rect)
        case .bar:
            drawBarGrid(ctx, rect: rect)
        case .twoBar:
            drawTwoBarGrid(ctx, rect: rect)
        case .fourBar:
            drawFourBarGrid(ctx, rect: rect)
        }
    }
    
    // Draw sixteenth note grid (most detailed)
    private func drawSixteenthNoteGrid(_ ctx: CGContext, rect: CGRect) {
        let beatsPerBar = Double(timeSignatureBeats)
        let pixelsPerBar = pixelsPerBeat * beatsPerBar
        
        // Calculate visible bar range
        let startX = rect.minX
        let endX = rect.maxX
        let startBar = Int(floor(startX / CGFloat(pixelsPerBar)))
        let endBar = Int(ceil(endX / CGFloat(pixelsPerBar)))
        
        // Draw bar lines and all subdivisions
        for barIndex in startBar...endBar {
            // Draw bar line
            let barX = CGFloat(Double(barIndex) * pixelsPerBar)
            if barX >= startX && barX <= endX {
                drawLine(in: ctx, at: barX, height: rect.height, color: barLineColor, lineWidth: 1.0)
            }
            
            // Draw half-bar lines
            let halfBarX = barX + CGFloat(pixelsPerBar / 2)
            if halfBarX >= startX && halfBarX <= endX {
                drawLine(in: ctx, at: halfBarX, height: rect.height, color: halfBarLineColor, lineWidth: 1.0)
            }
            
            // Draw quarter-bar lines (beats)
            for quarterOffset in [0.25, 0.75] {
                let quarterX = barX + CGFloat(pixelsPerBar * quarterOffset)
                if quarterX >= startX && quarterX <= endX {
                    drawLine(in: ctx, at: quarterX, height: rect.height, color: quarterBarLineColor, lineWidth: 0.8)
                }
            }
            
            // Draw eighth-note lines
            let eighths = [0.125, 0.375, 0.625, 0.875]
            for eighthOffset in eighths {
                let eighthX = barX + CGFloat(pixelsPerBar * eighthOffset)
                if eighthX >= startX && eighthX <= endX {
                    drawLine(in: ctx, at: eighthX, height: rect.height, color: eighthBarLineColor, lineWidth: 0.7)
                }
            }
            
            // Draw sixteenth-note lines
            let sixteenths = [0.0625, 0.1875, 0.3125, 0.4375, 0.5625, 0.6875, 0.8125, 0.9375]
            for sixteenthOffset in sixteenths {
                let sixteenthX = barX + CGFloat(pixelsPerBar * sixteenthOffset)
                if sixteenthX >= startX && sixteenthX <= endX {
                    drawLine(in: ctx, at: sixteenthX, height: rect.height, color: sixteenthBarLineColor, lineWidth: 0.6)
                }
            }
        }
    }
    
    // Draw eighth note grid
    private func drawEighthNoteGrid(_ ctx: CGContext, rect: CGRect) {
        let beatsPerBar = Double(timeSignatureBeats)
        let pixelsPerBar = pixelsPerBeat * beatsPerBar
        
        // Calculate visible bar range
        let startX = rect.minX
        let endX = rect.maxX
        let startBar = Int(floor(startX / CGFloat(pixelsPerBar)))
        let endBar = Int(ceil(endX / CGFloat(pixelsPerBar)))
        
        // Draw bar lines and subdivisions
        for barIndex in startBar...endBar {
            // Draw bar line
            let barX = CGFloat(Double(barIndex) * pixelsPerBar)
            if barX >= startX && barX <= endX {
                drawLine(in: ctx, at: barX, height: rect.height, color: barLineColor, lineWidth: 1.0)
            }
            
            // Draw half-bar lines
            let halfBarX = barX + CGFloat(pixelsPerBar / 2)
            if halfBarX >= startX && halfBarX <= endX {
                drawLine(in: ctx, at: halfBarX, height: rect.height, color: halfBarLineColor, lineWidth: 1.0)
            }
            
            // Draw quarter-bar lines (beats)
            for quarterOffset in [0.25, 0.75] {
                let quarterX = barX + CGFloat(pixelsPerBar * quarterOffset)
                if quarterX >= startX && quarterX <= endX {
                    drawLine(in: ctx, at: quarterX, height: rect.height, color: quarterBarLineColor, lineWidth: 0.8)
                }
            }
            
            // Draw eighth-note lines
            let eighths = [0.125, 0.375, 0.625, 0.875]
            for eighthOffset in eighths {
                let eighthX = barX + CGFloat(pixelsPerBar * eighthOffset)
                if eighthX >= startX && eighthX <= endX {
                    drawLine(in: ctx, at: eighthX, height: rect.height, color: eighthBarLineColor, lineWidth: 0.7)
                }
            }
        }
    }
    
    // Draw quarter note grid
    private func drawQuarterNoteGrid(_ ctx: CGContext, rect: CGRect) {
        let beatsPerBar = Double(timeSignatureBeats)
        let pixelsPerBar = pixelsPerBeat * beatsPerBar
        
        // Calculate visible bar range
        let startX = rect.minX
        let endX = rect.maxX
        let startBar = Int(floor(startX / CGFloat(pixelsPerBar)))
        let endBar = Int(ceil(endX / CGFloat(pixelsPerBar)))
        
        // Draw bar lines and beats
        for barIndex in startBar...endBar {
            // Draw bar line
            let barX = CGFloat(Double(barIndex) * pixelsPerBar)
            if barX >= startX && barX <= endX {
                drawLine(in: ctx, at: barX, height: rect.height, color: barLineColor, lineWidth: 1.0)
            }
            
            // Draw half-bar lines
            let halfBarX = barX + CGFloat(pixelsPerBar / 2)
            if halfBarX >= startX && halfBarX <= endX {
                drawLine(in: ctx, at: halfBarX, height: rect.height, color: halfBarLineColor, lineWidth: 1.0)
            }
            
            // Draw quarter-bar lines (beats)
            for quarterOffset in [0.25, 0.75] {
                let quarterX = barX + CGFloat(pixelsPerBar * quarterOffset)
                if quarterX >= startX && quarterX <= endX {
                    drawLine(in: ctx, at: quarterX, height: rect.height, color: quarterBarLineColor, lineWidth: 0.8)
                }
            }
        }
    }
    
    // Draw half-bar grid
    private func drawHalfBarGrid(_ ctx: CGContext, rect: CGRect) {
        let beatsPerBar = Double(timeSignatureBeats)
        let pixelsPerBar = pixelsPerBeat * beatsPerBar
        
        // Calculate visible bar range
        let startX = rect.minX
        let endX = rect.maxX
        let startBar = Int(floor(startX / CGFloat(pixelsPerBar)))
        let endBar = Int(ceil(endX / CGFloat(pixelsPerBar)))
        
        // Draw bar lines and half-bar markers
        for barIndex in startBar...endBar {
            // Draw bar line
            let barX = CGFloat(Double(barIndex) * pixelsPerBar)
            if barX >= startX && barX <= endX {
                drawLine(in: ctx, at: barX, height: rect.height, color: barLineColor, lineWidth: 1.0)
            }
            
            // Draw half-bar lines
            let halfBarX = barX + CGFloat(pixelsPerBar / 2)
            if halfBarX >= startX && halfBarX <= endX {
                drawLine(in: ctx, at: halfBarX, height: rect.height, color: halfBarLineColor, lineWidth: 1.0)
            }
        }
    }
    
    // Draw bar grid (only bar lines)
    private func drawBarGrid(_ ctx: CGContext, rect: CGRect) {
        let beatsPerBar = Double(timeSignatureBeats)
        let pixelsPerBar = pixelsPerBeat * beatsPerBar
        
        // Calculate visible bar range
        let startX = rect.minX
        let endX = rect.maxX
        let startBar = Int(floor(startX / CGFloat(pixelsPerBar)))
        let endBar = Int(ceil(endX / CGFloat(pixelsPerBar)))
        
        // Draw only bar lines
        for barIndex in startBar...endBar {
            let barX = CGFloat(Double(barIndex) * pixelsPerBar)
            if barX >= startX && barX <= endX {
                drawLine(in: ctx, at: barX, height: rect.height, color: barLineColor, lineWidth: 1.0)
            }
        }
    }
    
    // Draw two-bar grid (every other bar)
    private func drawTwoBarGrid(_ ctx: CGContext, rect: CGRect) {
        let beatsPerBar = Double(timeSignatureBeats)
        let pixelsPerBar = pixelsPerBeat * beatsPerBar
        
        // Calculate visible bar range
        let startX = rect.minX
        let endX = rect.maxX
        let startBar = Int(floor(startX / CGFloat(pixelsPerBar)))
        let endBar = Int(ceil(endX / CGFloat(pixelsPerBar)))
        
        // Draw bar lines for every other bar
        for barIndex in stride(from: startBar, through: endBar, by: 2) {
            let barX = CGFloat(Double(barIndex) * pixelsPerBar)
            if barX >= startX && barX <= endX {
                drawLine(in: ctx, at: barX, height: rect.height, color: barLineColor, lineWidth: 1.0)
            }
        }
    }
    
    // Draw four-bar grid (every fourth bar)
    private func drawFourBarGrid(_ ctx: CGContext, rect: CGRect) {
        let beatsPerBar = Double(timeSignatureBeats)
        let pixelsPerBar = pixelsPerBeat * beatsPerBar
        
        // Calculate visible bar range
        let startX = rect.minX
        let endX = rect.maxX
        let startBar = Int(floor(startX / CGFloat(pixelsPerBar)))
        let endBar = Int(ceil(endX / CGFloat(pixelsPerBar)))
        
        // Draw bar lines for every fourth bar
        for barIndex in stride(from: startBar, through: endBar, by: 4) {
            let barX = CGFloat(Double(barIndex) * pixelsPerBar)
            if barX >= startX && barX <= endX {
                drawLine(in: ctx, at: barX, height: rect.height, color: barLineColor, lineWidth: 1.0)
            }
        }
    }
    
    // MARK: - Layout
    
    override func layout() {
        super.layout()
        
        let totalWidth = getTotalWidth()
        
        // Update layer frames
        backgroundLayer?.frame = CGRect(x: 0, y: 0, width: totalWidth, height: bounds.height)
        gridLayer?.frame = CGRect(x: 0, y: 0, width: totalWidth, height: bounds.height)
        
        // Update cached viewport width
        lastViewportWidth = bounds.width
    }
    
    // Calculate the total width required
    private func getTotalWidth() -> CGFloat {
        let beatsPerBar = Double(timeSignatureBeats)
        let pixelsPerBar = pixelsPerBeat * beatsPerBar
        return CGFloat(totalBars + 1) * CGFloat(pixelsPerBar)
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
    
    // Cleanup when view is removed
    deinit {
        if let displayLink = displayLink {
            CVDisplayLinkStop(displayLink)
        }
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
        backgroundLayer?.masksToBounds = false
    }
}

// MARK: - CALayerDelegate for Tiled Layer

extension TimelineGridNSView: CALayerDelegate {
    func draw(_ layer: CALayer, in ctx: CGContext) {
        // Skip if not our grid layer
        guard layer === gridLayer || layer === backgroundLayer else { return }
        
        // Get the visible rect that needs to be drawn
        let bounds = ctx.boundingBoxOfClipPath
        
        if layer === backgroundLayer {
            // Draw just the alternating bar backgrounds
            drawAlternatingBarBackgrounds(in: ctx, rect: bounds)
        } else if layer === gridLayer {
            // Draw the grid lines
            drawGridInRect(ctx, rect: bounds)
        }
    }
}

#Preview {
    AppKitTimelineGridView(
        state: TimelineStateViewModel(),
        projectViewModel: ProjectViewModel(),
        width: 800,
        height: 400
    )
    .environmentObject(ThemeManager())
} 