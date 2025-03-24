//
//  PianoRollKeysOnly.swift
//  music.ai.frontend
//
//  Created by Ben Dreyer on 3/24/25.
//

import SwiftUI

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
            ZStack(alignment: .top) {
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
        .frame(height: totalContentHeight, alignment: .top)
        .background(themeManager.tertiaryBackgroundColor)
        .clipped()
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
