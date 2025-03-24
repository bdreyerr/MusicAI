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
    
    // Track and clip IDs for looking up the clip
    let trackId: UUID
    let clipId: UUID
    
    // Computed property to get the current clip from the project
    private var midiClip: MidiClip? {
        guard let projectViewModel = midiEditorViewModel.projectViewModel,
              let track = projectViewModel.tracks.first(where: { $0.id == trackId }),
              let clip = track.midiClips.first(where: { $0.id == clipId }) else {
            return nil
        }
        return clip
    }
    
    // Scroll position state
    @State private var verticalScrollOffset: CGFloat = 0
    @State private var currentBeatPosition: Double = 0 // Track current visible position in beats
    
    // Constants for layout
    private let pianoRollWidth: CGFloat = 100
    private let velocityEditorHeight: CGFloat = 60
    private let controlsHeight: CGFloat = 30
    
    init(trackId: UUID, clipId: UUID) {
        self.trackId = trackId
        self.clipId = clipId
    }
    
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

                        // Draw mode button
                        Button(action: {
                            midiEditorViewModel.isDrawModeEnabled.toggle()
                        }) {
                            Image(systemName: "pencil")
                                .foregroundColor(midiEditorViewModel.isDrawModeEnabled ? themeManager.accentColor : themeManager.primaryTextColor)
                                .frame(width: 24, height: 24)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(midiEditorViewModel.isDrawModeEnabled ? themeManager.accentColor.opacity(0.2) : Color.clear)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(midiEditorViewModel.isDrawModeEnabled ? themeManager.accentColor : themeManager.secondaryBorderColor, lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .help("Toggle Draw Mode")
                        .padding(.horizontal, 4)
                        .keyboardShortcut("b", modifiers: [])
                        
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
                    ScrollView(.vertical, showsIndicators: false) {
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
                                    viewModel: midiEditorViewModel
                                )
                                .border(Color.red, width: 0)
                                .layoutPriority(1) // Ensure this takes up all available space
                            }
                            .frame(width: pianoRollWidth, alignment: .top) // Add top alignment
                            .border(themeManager.secondaryBorderColor, width: 0.5)
                            
                            // Grid area (horizontal scroll only)
                            ScrollViewReader { horizontalProxy in
                                ScrollView(.horizontal, showsIndicators: false) {
                                    VStack(spacing: 0) {
                                        // Grid ruler
                                        GridRulerView(viewModel: midiEditorViewModel, midiClip: midiClip)
                                            .frame(height: controlsHeight)
                                            .border(themeManager.secondaryBorderColor, width: 0.5)
                                        
                                        // Grid content matching piano roll height
                                        if let clip = midiClip {
                                            MidiGridEditorView(viewModel: midiEditorViewModel, trackId: trackId, clipId: clipId)
                                                .border(themeManager.secondaryBorderColor, width: 0.5)
                                        }
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

// Preference key for tracking scroll position
struct MidiEditorScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
