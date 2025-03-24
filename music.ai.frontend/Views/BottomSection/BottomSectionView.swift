import SwiftUI
import AppKit

/// Main container view for the bottom section of the application
struct BottomSectionView: View {
    @ObservedObject var projectViewModel: ProjectViewModel
    @StateObject private var midiEditorViewModel: MidiEditorViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isExpanded: Bool = true
    @State private var selectedTab: Int = 0 // 0 = Waveform/Piano Roll, 1 = Effects
    
    // State for resizing
    @State private var sectionHeight: CGFloat = 300
    @State private var isHoveringResizeArea: Bool = false
    @State private var isDraggingResize: Bool = false
    @State private var dragStartY: CGFloat = 0
    @State private var dragStartHeight: CGFloat = 0
    @State private var lastDragLocation: CGFloat = 0 // Track last drag location to prevent jitter
    
    // Minimum heights
    private let collapsedHeight: CGFloat = 40
    private let minExpandedHeight: CGFloat = 160
    private let maxExpandedHeight: CGFloat = 800
    private let resizeAreaHeight: CGFloat = 8
    
    // Animation settings
    private let resizeAnimation = Animation.interpolatingSpring(mass: 0.1, stiffness: 170, damping: 18, initialVelocity: 0)
    private let expandCollapseAnimation = Animation.spring(response: 0.3, dampingFraction: 0.7)
    
    // Initialize the view and set up the MidiEditorViewModel with projectViewModel
    init(projectViewModel: ProjectViewModel) {
        self.projectViewModel = projectViewModel
        let viewModel = MidiEditorViewModel()
        viewModel.projectViewModel = projectViewModel
        self._midiEditorViewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Keyboard shortcuts layer (invisible)
            KeyboardShortcutsBottomSection()
                .environmentObject(midiEditorViewModel)
                .frame(width: 0, height: 0)
            
            // Resize handle area at the top
            Rectangle()
                .fill(Color.clear)
                .frame(height: resizeAreaHeight)
                .background(isHoveringResizeArea ? themeManager.tertiaryBackgroundColor.opacity(0.5) : Color.clear)
                .contentShape(Rectangle()) // Improve drag gesture detection
                .onHover { hovering in
                    isHoveringResizeArea = hovering
                    if hovering && !isDraggingResize {
                        NSCursor.resizeUpDown.set()
                    } else if !isDraggingResize {
                        NSCursor.arrow.set()
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 2, coordinateSpace: .global)
                        .onChanged { value in
                            // Set initial state on first detection
                            if !isDraggingResize {
                                isDraggingResize = true
                                dragStartY = value.startLocation.y
                                dragStartHeight = sectionHeight
                                lastDragLocation = value.location.y
                                NSCursor.resizeUpDown.set()
                            }
                            
                            // Calculate movement delta - check if movement is significant to avoid micro-jitters
                            let currentY = value.location.y
                            let dragDelta = dragStartY - currentY
                            
                            // Only update if movement is significant enough (prevents micro-jitters)
                            if abs(lastDragLocation - currentY) > 0.5 {
                                let newHeight = max(minExpandedHeight, min(maxExpandedHeight, dragStartHeight + dragDelta))
                                
                                // Apply animation when not dragging for smoother transitions
                                withAnimation(isDraggingResize ? nil : resizeAnimation) {
                                    sectionHeight = newHeight
                                }
                                lastDragLocation = currentY
                            }
                        }
                        .onEnded { _ in
                            // Reset state
                            isDraggingResize = false
                            if isHoveringResizeArea {
                                NSCursor.resizeUpDown.set()
                            } else {
                                NSCursor.arrow.set()
                            }
                        }
                )
                .zIndex(1) // Ensure resize handle is above other content
            
            // Header bar with toggle
            HStack {
                // Switch between (piano roll / audio waveform) and effects rack
                Button(action: {
                    self.selectedTab = (self.selectedTab + 1) % 2
                }) {
                    EmptyView()
                }
                .keyboardShortcut(.tab, modifiers: [])
                .frame(width: 0, height: 0)
                .hidden()
                
                // Open / Expand
                Button(action: {
                    self.isExpanded = true
                }) {
                    EmptyView()
                }
                .keyboardShortcut(.upArrow, modifiers: [.option])
                .frame(width: 0, height: 0)
                .hidden()
                
                Button(action: {
                    self.isExpanded = false
                }) {
                    EmptyView()
                }
                .keyboardShortcut(.downArrow, modifiers: [.option])
                .frame(width: 0, height: 0)
                .hidden()
                
                Text("\(projectViewModel.selectedTrack?.name ?? "Track Inspector")")
                    .font(.headline)
                    .foregroundColor(themeManager.primaryTextColor)
                
                Spacer()
                
                if let selectedTrack = projectViewModel.selectedTrack {
                    if selectedTrack.type != .master {
                        // Custom tab bar at the bottom right
                        HStack(spacing: 0) {
                            Spacer()
                            
                            // Tab buttons container
                            HStack(spacing: 1) {
                                // First tab button
                                TabButton(
                                    title: selectedTrack.type == .audio ? "Waveform" : "Piano Roll",
                                    systemImage: selectedTrack.type == .audio ? "waveform" : "pianokeys",
                                    isSelected: selectedTab == 0,
                                    action: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedTab = 0
                                        }
                                    }
                                )
                                
                                // Second tab button
                                TabButton(
                                    title: "Effects",
                                    systemImage: "slider.horizontal.3",
                                    isSelected: selectedTab == 1,
                                    action: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedTab = 1
                                        }
                                    }
                                )
                            }
                            .frame(width: 300)
                            .background(themeManager.tertiaryBackgroundColor)
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(themeManager.secondaryBorderColor, lineWidth: 1)
                            )
                            .padding(8)
                            .opacity(self.isExpanded ? 1 : 0)
                        }
                    }
                }
                
                // Toggle to expand/collapse the bottom section
                Button(action: {
                    withAnimation(expandCollapseAnimation) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                        .foregroundColor(themeManager.primaryTextColor)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(BorderlessButtonStyle())
                .help(isExpanded ? "Collapse" : "Expand")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(themeManager.tertiaryBackgroundColor)
            .border(themeManager.secondaryBorderColor, width: 0.5)
            
            // Content area - only shown when expanded
            if isExpanded {
                VStack(spacing: 0) {
                    // Main content area
                    if let selectedTrack = projectViewModel.selectedTrack {
                        if selectedTrack.type != .master {
                            // Content container
                            ZStack(alignment: .bottomTrailing) {
                                // First tab: Waveform for audio tracks, Piano Roll for MIDI tracks
                                Group {
                                    if selectedTrack.type == .audio {
                                        AudioWaveformView(track: selectedTrack, projectViewModel: projectViewModel)
                                    } else if selectedTrack.type == .midi {
                                        MIDIPianoRollView(track: selectedTrack, projectViewModel: projectViewModel)
                                    }
                                }
                                .opacity(selectedTab == 0 ? 1 : 0)
                                
                                // Second tab: Effects
                                EffectsRackView(projectViewModel: projectViewModel)
                                    .opacity(selectedTab == 1 ? 1 : 0)
                            }
                        } else {
                            // Master track only shows effects
                            EffectsRackView(projectViewModel: projectViewModel)
                        }
                    } else {
                        // No track selected
                        VStack {
                            Spacer()
                            Text("No track selected")
                                .foregroundColor(themeManager.secondaryTextColor)
                            Spacer()
                        }
                    }
                }
                .frame(height: sectionHeight - collapsedHeight)
            }
        }
        .frame(height: isExpanded ? sectionHeight : collapsedHeight)
        .background(themeManager.secondaryBackgroundColor)
        .overlay(
            // Top border
            Rectangle()
                .fill(themeManager.secondaryBorderColor)
                .frame(height: 0.5)
                .offset(y: -0.25),
            alignment: .top
        )
        .animation(isDraggingResize ? nil : resizeAnimation, value: sectionHeight)
        .animation(expandCollapseAnimation, value: isExpanded)
        .environmentObject(midiEditorViewModel)
    }
}

// Custom tab button view
struct TabButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(title)
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(isSelected ? themeManager.secondaryBackgroundColor : Color.clear)
            .foregroundColor(isSelected ? themeManager.primaryTextColor : themeManager.secondaryTextColor)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isSelected ? themeManager.primaryTextColor : themeManager.secondaryBorderColor, lineWidth: 1)
            )
        }
        .buttonStyle(BorderlessButtonStyle())
        .contentShape(Rectangle())
    }
}

// A struct to seed the random generator for consistent results
private struct SeededRandomGenerator {
    private var seed: Int
    
    init(seed: Int) {
        // Make sure we start with a positive seed
        self.seed = abs(seed) == 0 ? 42 : abs(seed)
    }
    
    mutating func randomCGFloat(min: CGFloat, max: CGFloat) -> CGFloat {
        // Use a simple but robust xorshift algorithm
        // This avoids overflow issues with large multiplications
        var x = UInt32(truncatingIfNeeded: seed)
        x ^= x << 13
        x ^= x >> 17
        x ^= x << 5
        seed = Int(x)
        
        // Convert to normalized float in [0,1] range
        let normalizedValue = CGFloat(seed & 0x7FFFFFFF) / CGFloat(0x7FFFFFFF)
        
        // Scale to requested range
        return min + normalizedValue * (max - min)
    }
}

// Placeholder view for audio waveform visualization
struct AudioWaveformView: View {
    let track: Track
    @ObservedObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    // Generate random waveform data (similar to AudioClipView)
    private let waveformData: [CGFloat]
    
    init(track: Track, projectViewModel: ProjectViewModel) {
        self.track = track
        self.projectViewModel = projectViewModel
        
        // Generate placeholder waveform data
        var generator = SeededRandomGenerator(seed: track.id.hashValue)
        var data = [CGFloat]()
        for _ in 0..<200 {
            data.append(generator.randomCGFloat(min: 0.1, max: 1.0))
        }
        self.waveformData = data
    }
    
    // Computed property to get the selected clip
    private var selectedClip: AudioClip? {
        guard let timelineState = projectViewModel.timelineState,
              timelineState.selectionActive,
              projectViewModel.selectedTrackId == track.id else {
            return nil
        }
        
        // Get the selection range
        let (selStart, selEnd) = timelineState.normalizedSelectionRange
        
        // Find the clip that matches the selection range
        return track.audioClips.first { clip in
            abs(clip.startBeat - selStart) < 0.001 &&
            abs(clip.endBeat - selEnd) < 0.001
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            if projectViewModel.audioViewModel.isAudioClipSelected(trackId: track.id),
               let clip = selectedClip {
                VStack(alignment: .leading, spacing: 0) {
                    // Clip name and info
                    HStack {
                        Text(clip.name)
                            .font(.headline)
                            .foregroundColor(themeManager.primaryTextColor)
                        
                        Spacer()
                        
                        Text("Duration: \(String(format: "%.2f", clip.duration)) beats")
                            .font(.caption)
                            .foregroundColor(themeManager.secondaryTextColor)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                    
                    // Waveform visualization
                    StripedWaveformView(
                        waveformData: waveformData,
                        color: track.effectiveColor,
                        width: geometry.size.width - 32,
                        height: geometry.size.height - 80
                    )
                    .padding(.horizontal, 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(themeManager.secondaryBackgroundColor)
            } else {
                // No clip selected
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "waveform.slash")
                                .font(.system(size: 32))
                                .foregroundColor(themeManager.secondaryTextColor)
                            Text("No Clip Selected")
                                .font(.headline)
                                .foregroundColor(themeManager.secondaryTextColor)
                            Text("Select an audio clip to view its waveform")
                                .font(.caption)
                                .foregroundColor(themeManager.secondaryTextColor.opacity(0.8))
                        }
                        Spacer()
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(themeManager.secondaryBackgroundColor)
            }
        }
    }
}

// Placeholder view for MIDI piano roll
struct MIDIPianoRollView: View {
    let track: Track
    @ObservedObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    // Computed property to get the selected clip
    private var selectedClip: MidiClip? {
        guard let timelineState = projectViewModel.timelineState,
              timelineState.selectionActive,
              projectViewModel.selectedTrackId == track.id else {
            return nil
        }
        
        // Get the selection range
        let (selStart, selEnd) = timelineState.normalizedSelectionRange
        
        // Find the clip that matches the selection range
        return track.midiClips.first { clip in
            abs(clip.startBeat - selStart) < 0.001 &&
            abs(clip.endBeat - selEnd) < 0.001
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            if projectViewModel.midiViewModel.isMidiClipSelected(trackId: track.id),
               let clip = selectedClip {
                VStack(alignment: .leading, spacing: 0) {
                    // TODO: Find a way to add back clip name and length
                    
                    // Piano roll editor (Previous)
                    // HStack(spacing: 0) {
                    //     // Piano roll on the left
                    //     PianoRoll(midiClip: clip)
                    //         .frame(width: 100) // Increased width to accommodate zoom controls and labels
                        
                    //     // Space for future MIDI notes editor
                    //     ZStack {
                    //         Rectangle()
                    //             .fill(themeManager.secondaryBackgroundColor)
                            
                    //         Text("MIDI Notes Editor")
                    //             .font(.headline)
                    //             .foregroundColor(themeManager.secondaryTextColor)
                    //     }
                    // }
                    // .frame(maxWidth: .infinity, maxHeight: .infinity)

                    MidiClipEditorContainerView(trackId: track.id, clipId: clip.id)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(themeManager.secondaryBackgroundColor)
            } else {
                // No clip selected
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "pianokeys")
                                .font(.system(size: 32))
                                .foregroundColor(themeManager.secondaryTextColor)
                            Text("No Clip Selected")
                                .font(.headline)
                                .foregroundColor(themeManager.secondaryTextColor)
                            Text("Select a MIDI clip to view the piano roll")
                                .font(.caption)
                                .foregroundColor(themeManager.secondaryTextColor.opacity(0.8))
                        }
                        Spacer()
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(themeManager.secondaryBackgroundColor)
            }
        }
    }
}

#Preview {
    BottomSectionView(projectViewModel: ProjectViewModel())
        .environmentObject(ThemeManager())
}
