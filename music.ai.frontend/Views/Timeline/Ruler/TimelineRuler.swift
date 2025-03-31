import SwiftUI

/// TimelineRuler shows bar, beat, and division markers at the top of the timeline
/// It adjusts what it displays based on the current zoom level
struct TimelineRuler: View {
    @ObservedObject var state: TimelineStateViewModel
    @ObservedObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var themeManager: ThemeManager
    let width: CGFloat
    let height: CGFloat
    
    // Add typealias for easier reference to GridDivision enum
    private typealias GridDivision = TimelineStateViewModel.GridDivision
    
    // --- Intermediate State for Static Content ---
    @State private var staticZoomLevel: Int = 0
    @State private var staticEffectivePixelsPerBeat: Double = 0
    @State private var staticTimeSignatureBeats: Int = 4
    @State private var staticTotalBars: Int = 0
    @State private var staticRulerHeight: CGFloat = 0
    // --- End Intermediate State ---
    
    // Variables to handle hover state for buttons
    @State private var isHoveringTimeline: Bool = false
    @State private var showingGridOptions: Bool = false
    
    // Button positioning - center horizontally by default
    private var buttonPositionX: CGFloat {
        width / 2
    }
    
    // Label for displaying the current grid division
    private var gridDivisionLabel: String {
        switch state.gridDivision {
        case .sixteenth: return "1/16"
        case .eighth: return "1/8"
        case .quarter: return "1/4"
        case .half: return "1/2"
        case .bar: return "Bar"
        case .twoBar: return "2 Bar"
        case .fourBar: return "4 Bar"
        }
    }
    
    // Generate a unique ID for the ruler to force redraw when needed
    private var rulerContentId: String {
        "ruler-\(staticZoomLevel)-\(Int(staticEffectivePixelsPerBeat))-\(staticTimeSignatureBeats)-\(staticTotalBars)-\(themeManager.themeChangeIdentifier)"
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Use GeometryReader primarily for the tap gesture location calculation
            GeometryReader { geo in
                // Container for the static content, applying clipping and frame
                ZStack(alignment: .topLeading) { // Align static content to topLeading
                    // Instantiate the static ruler content view using intermediate state
                    RulerStaticContentView(
                        zoomLevel: staticZoomLevel,
                        effectivePixelsPerBeat: staticEffectivePixelsPerBeat,
                        timeSignatureBeats: staticTimeSignatureBeats,
                        totalBars: staticTotalBars,
                        rulerHeight: staticRulerHeight,
                        viewportScrollOffset: state.scrollOffset,
                        viewportWidth: width
                    )
                    .environmentObject(themeManager)
                    // Apply the horizontal scroll offset (driven by original state)
                    .offset(x: -state.scrollOffset.x)
                    .id(rulerContentId) // Force redraw when key parameters change
                }
                .frame(width: width, height: height) // Set the frame for the visible area
                .clipped() // Clip the overflowing static content
                .contentShape(Rectangle()) // Ensure gestures work on the whole area
                .onHover { hovering in
                    isHoveringTimeline = hovering
                }
            }
            // --- Add onChange modifiers to update intermediate state ---    
            .onChange(of: state.zoomLevel) { _, newValue in staticZoomLevel = newValue }
            .onChange(of: state.effectivePixelsPerBeat) { _, newValue in staticEffectivePixelsPerBeat = newValue }
            .onChange(of: projectViewModel.timeSignatureBeats) { _, newValue in staticTimeSignatureBeats = newValue }
            .onChange(of: state.totalBars) { _, newValue in staticTotalBars = newValue }
            .onChange(of: height) { _, newValue in staticRulerHeight = newValue }
            // Initialize state on appear
            .onAppear {
                staticZoomLevel = state.zoomLevel
                staticEffectivePixelsPerBeat = state.effectivePixelsPerBeat
                staticTimeSignatureBeats = projectViewModel.timeSignatureBeats
                staticTotalBars = state.totalBars
                staticRulerHeight = height
            }
            // --- End onChange modifiers --- 
            
            // Buttons for grid snap and zoom (positioned with ZStack)
            HStack(spacing: 12) {
                // Grid snap button
                Button(action: {
                    showingGridOptions = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.grid.3x3")
                            .font(.system(size: 11))
                        Text(gridDivisionLabel)
                            .font(.system(size: 11))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(themeManager.secondaryBackgroundColor.opacity(0.9))
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(themeManager.borderColor, lineWidth: 1)
                    )
                }
                .buttonStyle(BorderlessButtonStyle())
                .popover(isPresented: $showingGridOptions) {
                    VStack(spacing: 8) {
                        Text("Grid Division")
                            .font(.headline)
                            .padding(.top, 8)
                        
                        Divider()
                        
                        ForEach(GridDivision.allCases, id: \.self) { division in
                            Button(action: {
                                // Use DispatchQueue.main.async to prevent state updates during view update
                                DispatchQueue.main.async {
                                    // Set zoom level based on the selected grid division
                                    state.setZoomLevelForGridDivision(division)
                                    showingGridOptions = false
                                }
                            }) {
                                HStack {
                                    Text(division.description)
                                        .frame(width: 100, alignment: .leading)
                                    Spacer()
                                    if state.gridDivision == division {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                        }
                    }
                    .frame(width: 150)
                    .padding(.bottom, 8)
                }
                
                // Zoom buttons
                HStack(spacing: 2) {
                    Button(action: {
                        // Use DispatchQueue.main.async to prevent state updates during view update
                        DispatchQueue.main.async {
                            state.zoomOut()
                        }
                    }) {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(themeManager.secondaryBackgroundColor.opacity(0.9))
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(themeManager.borderColor, lineWidth: 1)
                    )
                    
                    Button(action: {
                        // Use DispatchQueue.main.async to prevent state updates during view update
                        DispatchQueue.main.async {
                            state.zoomIn()
                        }
                    }) {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(themeManager.secondaryBackgroundColor.opacity(0.9))
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(themeManager.borderColor, lineWidth: 1)
                    )
                }
            }
            .position(x: buttonPositionX, y: height - 10) // Positioned within the ZStack
            .opacity(isHoveringTimeline ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.2), value: isHoveringTimeline)
        }
        .frame(height: height) // Set a fixed height for the entire ruler component
    }
    
    // Snap a beat position to the appropriate grid division based on zoom level
    private func snapToNearestGridMarker(_ rawBeatPosition: Double) -> Double {
        // Determine the smallest visible grid division based on zoom level
        let timeSignature = projectViewModel.timeSignatureBeats
        
        switch state.gridDivision {
        case .sixteenth:
            // Snap to sixteenth notes (0.0625 beat)
            return round(rawBeatPosition * 16.0) / 16.0
            
        case .eighth:
            // Snap to eighth notes (0.125 beat)
            return round(rawBeatPosition * 8.0) / 8.0
            
        case .quarter:
            // Snap to quarter notes (0.25 beat)
            return round(rawBeatPosition * 4.0) / 4.0
            
        case .half:
            // For half-bar markers (assuming 4/4 time, this would be beat 2)
            let beatsPerBar = Double(timeSignature)
            
            // Calculate the bar index and position within the bar
            let barIndex = floor(rawBeatPosition / beatsPerBar)
            let positionInBar = rawBeatPosition - (barIndex * beatsPerBar)
            
            // Check if we're closer to the start or middle of the bar
            if positionInBar < beatsPerBar / 4.0 {
                // Snap to start of bar
                return barIndex * beatsPerBar
            } else if positionInBar > (beatsPerBar * 3.0) / 4.0 {
                // Snap to start of next bar
                return (barIndex + 1) * beatsPerBar
            } else {
                // Snap to half-bar
                return barIndex * beatsPerBar + beatsPerBar / 2.0
            }
            
        case .bar:
            // When zoomed out, snap to bars
            let beatsPerBar = Double(timeSignature)
            return round(rawBeatPosition / beatsPerBar) * beatsPerBar
            
        case .twoBar:
            // When zoomed way out, snap to every two bars
            let beatsPerTwoBars = Double(timeSignature) * 2.0
            return round(rawBeatPosition / beatsPerTwoBars) * beatsPerTwoBars
            
        case .fourBar:
            // When zoomed way out, snap to every four bars
            let beatsPerFourBars = Double(timeSignature) * 4.0
            return round(rawBeatPosition / beatsPerFourBars) * beatsPerFourBars
        }
    }
}

#Preview {
    TimelineRuler(
        state: TimelineStateViewModel(),
        projectViewModel: ProjectViewModel(),
        width: 800,
        height: 25
    )
    .environmentObject(ThemeManager())
} 
