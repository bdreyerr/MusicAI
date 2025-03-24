//
//  PianoRoll.swift
//  music.ai.frontend
//
//  Created by Ben Dreyer on 3/22/25.
//

import SwiftUI

/// A piano roll view showing notes from C-2 to C8 with interactive hover labels and zoom controls.
struct PianoRoll: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject var viewModel = MidiEditorViewModel()
    
    // Optional clip to display
    var midiClip: MidiClip?
    
    // Width of the piano roll keys and labels
    private let keyWidth: CGFloat = 60
    private let labelWidth: CGFloat = 40
    private let velocityHeight: CGFloat = 60
    private let controlsHeight: CGFloat = 30
    
    // Piano note names
    private let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 0) {
                    // Zoom controls
                    HStack {
                        Button(action: viewModel.zoomOut) {
                            Image(systemName: "minus.magnifyingglass")
                                .foregroundColor(themeManager.primaryTextColor)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .disabled(viewModel.zoomLevel <= 0)
                        .padding(.horizontal, 4)
                        
                        // Show current zoom level (text indicator)
                        Text("Zoom: \(viewModel.zoomLevel + 1)/\(viewModel.zoomMultipliers.count)")
                            .font(.system(size: 10))
                            .foregroundColor(themeManager.secondaryTextColor)
                        
                        Spacer()
                        
                        Button(action: viewModel.zoomIn) {
                            Image(systemName: "plus.magnifyingglass")
                                .foregroundColor(themeManager.primaryTextColor)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .disabled(viewModel.zoomLevel >= viewModel.zoomMultipliers.count - 1)
                        .padding(.horizontal, 4)
                    }
                    .frame(height: controlsHeight)
                    .padding(.horizontal, 4)
                    .background(themeManager.tertiaryBackgroundColor)
                    
                    // Piano roll area 
                    ZStack(alignment: .top) {
                        ScrollViewReader { scrollProxy in
                            ScrollView(.vertical, showsIndicators: false) {
                                // Calculate total content height based on zoom
                                let keyHeight = viewModel.getKeyHeight()
                                let totalContentHeight = viewModel.calculatePianoRollContentHeight()
                                    
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
                                                    .frame(width: labelWidth, alignment: .leading)
                                                    .padding(.leading, 4)
                                                    .position(x: labelWidth/2, y: yPosition + keyHeight/2)
                                                    .zIndex(1)
                                                
                                                // Line below each octave
                                                Rectangle()
                                                    .fill(themeManager.secondaryBorderColor)
                                                    .frame(width: labelWidth, height: 1)
                                                    .position(x: labelWidth/2, y: yPosition + keyHeight)
                                            }
                                        }
                                        
                                        // Hover label
                                        if let hoveredKey = viewModel.hoveredKey {
                                            let yPosition = CGFloat(viewModel.fullEndNote - hoveredKey) * keyHeight
                                            Text(getNoteName(midiNote: hoveredKey))
                                                .font(.system(size: viewModel.getAdaptiveFontSize()))
                                                .fontWeight(.medium)
                                                .foregroundColor(themeManager.primaryTextColor)
                                                .frame(width: labelWidth, alignment: .leading)
                                                .padding(.leading, 4)
                                                .position(x: labelWidth/2, y: yPosition + keyHeight/2)
                                                .zIndex(2)
                                        }
                                    }
                                    .frame(width: labelWidth)
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
                                        
                                        // Draw piano keys
                                        pianoKeysView(keyHeight: keyHeight, totalContentHeight: totalContentHeight)
                                    }
                                    .frame(width: keyWidth)
                                }
                                .frame(height: totalContentHeight)
                            }
                            .onChange(of: viewModel.zoomLevel) { _, _ in
                                // When zoom changes, use the last centered note for consistent positioning
                                scrollToCenterNote(proxy: scrollProxy, note: viewModel.lastCenteredNote)
                            }
                            .onChange(of: viewModel.hoveredKey) { _, newValue in
                                // When the hovered key changes via keyboard shortcuts, scroll to it
                                if let noteToCenter = newValue {
                                    scrollToCenterNote(proxy: scrollProxy, note: noteToCenter)
                                }
                            }
                            .onChange(of: viewModel.lastCenteredNote) { _, newValue in
                                // When the last centered note changes via navigation functions, scroll to it
                                scrollToCenterNote(proxy: scrollProxy, note: newValue)
                            }
                            .onAppear {
                                // Initial scroll to middle C or the last centered note
                                scrollToCenterNote(proxy: scrollProxy, note: viewModel.lastCenteredNote)
                            }
                        }
                    }
                    .frame(height: geometry.size.height - velocityHeight - controlsHeight)
                    .clipped()
                    
                    // Velocity section at the bottom
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
                        .frame(width: labelWidth)
                        .overlay(
                            Rectangle()
                                .fill(themeManager.secondaryBorderColor)
                                .frame(width: 1),
                            alignment: .trailing
                        )
                        
                        // Max velocity indicator
                        ZStack(alignment: .trailing) {
                            Rectangle()
                                .fill(themeManager.tertiaryBackgroundColor)
                            
                            Text("127")
                                .font(.system(size: 11))
                                .foregroundColor(themeManager.primaryTextColor)
                                .padding(.trailing, 4)
                        }
                        .frame(width: keyWidth)
                    }
                    .frame(height: velocityHeight)
                    .overlay(
                        Rectangle()
                            .fill(themeManager.secondaryBorderColor)
                            .frame(height: 1),
                        alignment: .top
                    )
                }
                
                // Keyboard shortcuts layer (invisible)
                KeyboardShortcutsBottomSection()
                    .environmentObject(viewModel)
                    .frame(width: 0, height: 0)
            }
        }
        .environmentObject(viewModel)
    }
    
    // Get the available height for the piano area
    private func getPianoAreaHeight(geometry: GeometryProxy) -> CGFloat {
        return geometry.size.height - velocityHeight - controlsHeight
    }
    
    // Helper to scroll to a specific note
    private func scrollToCenterNote(proxy: ScrollViewProxy, note: Int) {
        withAnimation(.easeInOut(duration: 0.3)) {
            proxy.scrollTo(note, anchor: .center)
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
    
    // Helper view to render piano keys with proper hover detection
    private func pianoKeysView(keyHeight: CGFloat, totalContentHeight: CGFloat) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Draw all piano keys
                ForEach(viewModel.fullStartNote...viewModel.fullEndNote, id: \.self) { noteNumber in
                    let isBlack = isBlackKey(noteNumber: noteNumber)
                    let yPosition = CGFloat(viewModel.fullEndNote - noteNumber) * keyHeight
                    
                    // Key area for hover detection and display
                    Rectangle()
                        .fill(isBlack ? Color.black : Color.white)
                        .frame(width: keyWidth, height: max(1, keyHeight))  // Ensure minimum height
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
                                    .position(x: keyWidth/2, y: keyHeight - 0.5)
                            }
                        )
                        .position(x: keyWidth/2, y: yPosition + keyHeight/2)
                        .id(noteNumber) // For scroll positioning
                        .onTapGesture {
                            // When tapped, update both hover and last centered
                            viewModel.updateHoveredKey(noteNumber)
                            viewModel.lastCenteredNote = noteNumber
                        }
                }
            }
            .frame(height: totalContentHeight)
            // Adding a pointer event overlay to track hover position
            .overlay(
                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: keyWidth, height: totalContentHeight)
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            // Convert location to note number
                            let noteY = location.y
                            let noteIndex = Int((noteY / keyHeight).rounded(.down))
                            let calculatedNote = viewModel.fullEndNote - noteIndex
                            
                            // Ensure we're in valid range
                            if calculatedNote >= viewModel.fullStartNote && calculatedNote <= viewModel.fullEndNote {
                                // Prevent multiple updates in the same frame
                                viewModel.updateHoveredKey(calculatedNote)
                                // Don't update lastCenteredNote during hover to prevent jumping
                            }
                        case .ended:
                            viewModel.updateHoveredKey(nil)
                        }
                    }
            )
        }
    }
}

// Preview with theme manager
#Preview {
    PianoRoll()
        .environmentObject(ThemeManager())
        .frame(height: 400)
}

