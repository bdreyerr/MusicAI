//
//  MidiClipEditorContainerView.swift
//  music.ai.frontend
//
//  Created by Ben Dreyer on 3/23/25.
//

import SwiftUI

struct MidiClipEditorContainerView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var midiEditorViewModel: MidiEditorViewModel
    
    // MIDI clip to be edited
    var midiClip: MidiClip?
    
    // Scroll position state
    @State private var verticalScrollOffset: CGFloat = 0
    @State private var currentBeatPosition: Double = 0 // Track current visible position in beats
    
    // Constants for layout
    private let pianoRollWidth: CGFloat = 100
    private let velocityEditorHeight: CGFloat = 60
    private let controlsHeight: CGFloat = 30
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 0) {
                    // Top control area with zoom and grid controls
                    HStack {
                        // Zoom controls
                        HStack(spacing: 4) {
                            Button(action: midiEditorViewModel.zoomOut) {
                                Image(systemName: "minus.magnifyingglass")
                                    .foregroundColor(themeManager.primaryTextColor)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            .disabled(midiEditorViewModel.zoomLevel <= 0)
                            .padding(.horizontal, 4)
                            
                            Text("Zoom: \(midiEditorViewModel.zoomLevel + 1)/\(midiEditorViewModel.zoomMultipliers.count)")
                                .font(.system(size: 10))
                                .foregroundColor(themeManager.secondaryTextColor)
                            
                            Button(action: midiEditorViewModel.zoomIn) {
                                Image(systemName: "plus.magnifyingglass")
                                    .foregroundColor(themeManager.primaryTextColor)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            .disabled(midiEditorViewModel.zoomLevel >= midiEditorViewModel.zoomMultipliers.count - 1)
                            .padding(.horizontal, 4)
                        }
                        
                        Spacer()
                        
                        // Horizontal zoom controls for the grid
                        HStack(spacing: 4) {
                            Button(action: midiEditorViewModel.horizontalZoomOut) {
                                Image(systemName: "minus.rectangle")
                                    .foregroundColor(themeManager.primaryTextColor)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            .disabled(midiEditorViewModel.horizontalZoomLevel <= 0)
                            .padding(.horizontal, 4)
                            
                            Text("Beat: \(String(format: "%.1fx", midiEditorViewModel.horizontalZoomMultipliers[midiEditorViewModel.horizontalZoomLevel]))")
                                .font(.system(size: 10))
                                .foregroundColor(themeManager.secondaryTextColor)
                                .frame(width: 50, alignment: .center)
                            
                            Button(action: midiEditorViewModel.horizontalZoomIn) {
                                Image(systemName: "plus.rectangle")
                                    .foregroundColor(themeManager.primaryTextColor)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            .disabled(midiEditorViewModel.horizontalZoomLevel >= midiEditorViewModel.horizontalZoomMultipliers.count - 1)
                            .padding(.horizontal, 4)
                        }
                        
                        // Grid division selection
                        HStack(spacing: 4) {
                            Text("Grid:")
                                .font(.system(size: 10))
                                .foregroundColor(themeManager.secondaryTextColor)
                            
                            Picker("", selection: $midiEditorViewModel.gridDivision) {
                                ForEach(MidiEditorViewModel.GridDivision.allCases, id: \.self) { division in
                                    Text(division.label)
                                        .font(.system(size: 10))
                                        .tag(division)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(width: 60)
                            .labelsHidden()
                        }
                        .padding(.horizontal, 8)
                    }
                    .padding(.horizontal, 8)
                    .frame(height: controlsHeight)
                    .background(themeManager.tertiaryBackgroundColor)
                
                    // Main content area with piano roll and grid in shared scroll view
                    ScrollView(.vertical, showsIndicators: true) {
                        HStack(spacing: 0) {
                            // Piano roll keys with top label placeholder
                            VStack(spacing: 0) {
                                // Top-left empty space to align with ruler
                                Rectangle()
                                    .fill(themeManager.tertiaryBackgroundColor)
                                    .frame(height: controlsHeight)
                                    .border(themeManager.secondaryBorderColor, width: 0.5)
                                
                                // Piano roll keys
                                PianoRollKeysOnly(
                                    viewModel: midiEditorViewModel, midiClip: midiClip
                                )
                            }
                            .frame(width: pianoRollWidth)
                            
                            // Grid area (horizontal scroll only)
                            ScrollViewReader { horizontalProxy in
                                ScrollView(.horizontal, showsIndicators: true) {
                                    VStack(spacing: 0) {
                                        // Grid ruler
                                        GridRulerView(viewModel: midiEditorViewModel, midiClip: midiClip)
                                            .frame(height: controlsHeight)
                                            .border(themeManager.secondaryBorderColor, width: 0.5)
                                        
                                        // Grid content matching piano roll height - no padding or extra space
                                        GridContentView(viewModel: midiEditorViewModel, midiClip: midiClip)
                                            .frame(
                                                width: midiClip != nil 
                                                    ? midiEditorViewModel.calculateGridWidth(clipDuration: midiClip!.duration)
                                                    : 600,
                                                height: midiEditorViewModel.calculatePianoRollContentHeight()
                                            )
                                            // Add beat markers every 4 beats for scrolling
                                            .overlay(
                                                GeometryReader { geo in
                                                    ForEach(0..<40) { beatIndex in
                                                        Color.clear
                                                            .frame(width: 1, height: 1)
                                                            .position(
                                                                x: CGFloat(beatIndex) * midiEditorViewModel.pixelsPerBeat,
                                                                y: 0
                                                            )
                                                            .id("beat_\(beatIndex)")
                                                    }
                                                }
                                            )
                                    }
                                }
                                .onChange(of: midiEditorViewModel.horizontalZoomLevel) { oldValue, newValue in
                                    // Calculate the beat to focus on after zoom
                                    let beatToFocus = Int(currentBeatPosition.rounded(.down))
                                    // Animate scroll to this beat
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        horizontalProxy.scrollTo("beat_\(beatToFocus)", anchor: .leading)
                                    }
                                }
                                // Track the current beat position based on scroll
                                .background(
                                    GeometryReader { geo in
                                        Color.clear.preference(
                                            key: MidiEditorScrollOffsetPreferenceKey.self,
                                            value: geo.frame(in: .named("horizontalScroll")).minX
                                        )
                                    }
                                )
                                .coordinateSpace(name: "horizontalScroll")
                                .onPreferenceChange(MidiEditorScrollOffsetPreferenceKey.self) { value in
                                    // Convert scroll offset to beat position
                                    // (Negative value means we've scrolled right)
                                    if midiEditorViewModel.pixelsPerBeat > 0 {
                                        currentBeatPosition = Double(abs(value)) / Double(midiEditorViewModel.pixelsPerBeat)
                                    }
                                }
                            }
                        }
                        .border(themeManager.secondaryBorderColor, width: 0.5)
                    }
                    .frame(height: geometry.size.height - controlsHeight - velocityEditorHeight)
                    
                    // Velocity editor (extracted from PianoRoll)
                    HStack(spacing: 0) {
                        // Velocity label
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(themeManager.tertiaryBackgroundColor)
                            
                            Text("Velocity")
                                .font(.system(size: 8))
                                .fontWeight(.medium)
                                .foregroundColor(themeManager.primaryTextColor)
                                .padding(.leading, 4)
                        }
                        .frame(width: pianoRollWidth)
                        .border(themeManager.secondaryBorderColor, width: 0.5)
                        
                        // Max velocity indicator
                        ZStack(alignment: .trailing) {
                            Rectangle()
                                .fill(themeManager.tertiaryBackgroundColor)
                            
                            Text("127")
                                .font(.system(size: 11))
                                .foregroundColor(themeManager.primaryTextColor)
                                .padding(.trailing, 4)
                        }
                        .border(themeManager.secondaryBorderColor, width: 0.5)
                    }
                    .frame(height: velocityEditorHeight)
                }
            }
        }
        .environmentObject(midiEditorViewModel)
    }
}

// A modified version of PianoRoll that only renders the keys without internal scrolling
struct PianoRollKeysOnly: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var viewModel: MidiEditorViewModel
    
    var midiClip: MidiClip?
    
    // Width of the piano roll keys
    private let keyWidth: CGFloat = 100
    private let controlsHeight: CGFloat = 30
    
    // Piano note names
    private let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    
    var body: some View {
        // Calculate key height based on zoom
        let keyHeight = viewModel.getKeyHeight()
        let totalContentHeight = viewModel.calculatePianoRollContentHeight()
        
        // Stack for piano roll keys and labels
        HStack(spacing: 0) {
            // Labels section
            ZStack(alignment: .topLeading) {
                // Background
                Rectangle()
                    .fill(themeManager.tertiaryBackgroundColor)
                    .frame(height: totalContentHeight)
                
                // Octave labels
                ForEach((0...10).reversed(), id: \.self) { octave in
                    let midiNote = octave * 12 // C notes: C-2, C-1, C0, etc.
                    if midiNote <= viewModel.fullEndNote && midiNote >= viewModel.fullStartNote {
                        // Calculate Y position
                        let yPosition = CGFloat(viewModel.fullEndNote - midiNote) * keyHeight
                        
                        // Only show octave labels
                        Text(getNoteName(midiNote: midiNote))
                            .font(.system(size: viewModel.getAdaptiveFontSize()))
                            .fontWeight(.medium)
                            .foregroundColor(themeManager.primaryTextColor)
                            .frame(width: 40, alignment: .leading)
                            .padding(.leading, 4)
                            .position(x: 40/2, y: yPosition + keyHeight/2)
                            .zIndex(1)
                        
                        // Line below each octave
                        Rectangle()
                            .fill(themeManager.secondaryBorderColor)
                            .frame(width: 40, height: 1)
                            .position(x: 40/2, y: yPosition + keyHeight)
                    }
                }
                
                // Hover label
                if let hoveredKey = viewModel.hoveredKey {
                    let yPosition = CGFloat(viewModel.fullEndNote - hoveredKey) * keyHeight
                    Text(getNoteName(midiNote: hoveredKey))
                        .font(.system(size: viewModel.getAdaptiveFontSize()))
                        .fontWeight(.medium)
                        .foregroundColor(themeManager.primaryTextColor)
                        .frame(width: 40, alignment: .leading)
                        .padding(.leading, 4)
                        .position(x: 40/2, y: yPosition + keyHeight/2)
                        .zIndex(2)
                }
            }
            .frame(width: 40)
            .overlay(
                Rectangle()
                    .fill(themeManager.secondaryBorderColor)
                    .frame(width: 1),
                alignment: .trailing
            )
            
            // Piano keys
            ZStack(alignment: .topLeading) {
                // Background
                Rectangle()
                    .fill(themeManager.tertiaryBackgroundColor)
                    .frame(height: totalContentHeight)
                
                // Draw piano keys - Explicit positioning to match grid
                ForEach(0...(viewModel.fullEndNote - viewModel.fullStartNote), id: \.self) { index in
                    let noteNumber = viewModel.fullEndNote - index
                    let isBlack = isBlackKey(noteNumber: noteNumber)
                    let yPosition = CGFloat(index) * keyHeight
                    
                    // Key area for hover detection and display
                    Rectangle()
                        .fill(isBlack ? Color.black : Color.white)
                        .frame(width: 60, height: keyHeight)  // Exact height
                        .overlay(
                            Group {
                                // Show highlight when hovered
                                if viewModel.hoveredKey == noteNumber {
                                    Rectangle()
                                        .fill(themeManager.accentColor.opacity(0.3))
                                }
                                
                                // Bottom border
                                Rectangle()
                                    .fill(themeManager.secondaryBorderColor)
                                    .frame(height: 1)
                                    .position(x: 60/2, y: keyHeight - 0.5)
                            }
                        )
                        .position(x: 60/2, y: yPosition + keyHeight/2)
                        .onTapGesture {
                            // When tapped, update both hover and last centered properties
                            viewModel.updateHoveredKey(noteNumber)
                            viewModel.lastCenteredNote = noteNumber
                        }
                }
                
                // Hover detection overlay
                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: 60, height: totalContentHeight)
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            // Convert location to note number - match grid calculation exactly
                            let noteIndex = Int(location.y / keyHeight)
                            let calculatedNote = viewModel.fullEndNote - noteIndex
                            
                            // Ensure we're in valid range
                            if calculatedNote >= viewModel.fullStartNote && calculatedNote <= viewModel.fullEndNote {
                                // Prevent multiple updates in the same frame by checking if value changed
                                viewModel.updateHoveredKey(calculatedNote)
                                // Don't update lastCenteredNote during hover to prevent constant scrolling
                            }
                        case .ended:
                            viewModel.updateHoveredKey(nil)
                        }
                    }
            }
            .frame(width: 60)
        }
        .frame(height: totalContentHeight)
        .onChange(of: viewModel.zoomLevel) { _, _ in
            // Scroll container will handle this via ancestors
        }
        // Empty handler to avoid unnecessary updates
        .onChange(of: viewModel.hoveredKey) { _, _ in 
            // External scroll handling happens elsewhere
        }
    }
    
    // Check if a note is a black key
    private func isBlackKey(noteNumber: Int) -> Bool {
        let note = noteNumber % 12
        return [1, 3, 6, 8, 10].contains(note)
    }
    
    // Convert MIDI note number to note name (e.g., C3, F#4)
    private func getNoteName(midiNote: Int) -> String {
        let octave = (midiNote / 12) - 1
        let noteIndex = midiNote % 12
        return "\(noteNames[noteIndex])\(octave)"
    }
}

// Preference key for tracking scroll position
struct MidiEditorScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    MidiClipEditorContainerView()
        .environmentObject(ThemeManager())
        .frame(width: 800, height: 600)
}
