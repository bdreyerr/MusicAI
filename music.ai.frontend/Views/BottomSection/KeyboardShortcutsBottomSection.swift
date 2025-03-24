//
//  KeyboardShortcutsBottomSection.swift
//  music.ai.frontend
//
//  Created by Ben Dreyer on 3/22/25.
//

import SwiftUI

struct KeyboardShortcutsBottomSection: View {
    // Environment object for the MIDI editor ViewModel
    @EnvironmentObject var midiEditorViewModel: MidiEditorViewModel
    
    var body: some View {
        // Invisible buttons for keyboard shortcuts
        VStack {
            
            // Grid Zoom in
            
            // FOR SOME REASON THIS ONE DOESN'T WORK? IDK WHY LOL, it's like mac is not letting me press this or it's not recognizing it or something
            Button(action: {
                print("TEST ZOOM IN")
                midiEditorViewModel.horizontalZoomIn()
            }) {
                EmptyView()
            }
            .keyboardShortcut("+", modifiers: [.option])
            
            // Grid Zoom out
            Button(action: {
                midiEditorViewModel.horizontalZoomOut()
            }) {
                EmptyView()
            }
            .keyboardShortcut("-", modifiers: [.option])
            
            // Piano Roll Zoom in (simply +)
            Button(action: {
                midiEditorViewModel.zoomIn()
            }) {
                EmptyView()
            }
            .keyboardShortcut("+", modifiers: [])
            
            // Piano Roll Zoom out (simply -)
            Button(action: {
                midiEditorViewModel.zoomOut()
            }) {
                EmptyView()
            }
            .keyboardShortcut("-", modifiers: [])
            
            // Alternate zoom in (=)
            Button(action: {
                midiEditorViewModel.zoomIn()
            }) {
                EmptyView()
            }
            .keyboardShortcut("=", modifiers: [])
            
            // Navigation shortcuts
            
            // Go to Middle C (0)
            Button(action: {
                midiEditorViewModel.goToMiddleC()
            }) {
                EmptyView()
            }
            .keyboardShortcut("0", modifiers: [])
            
            // Go to octave shortcuts (1-9 for octaves -1 to 7)
//            ForEach(-1...7, id: \.self) { octave in
//                if octave >= -1 && octave <= 7 {
//                    Button(action: {
//                        midiEditorViewModel.goToOctave(octave)
//                    }) {
//                        EmptyView()
//                    }
//                    .keyboardShortcut("\(octave + 2)", modifiers: [])
//                }
//            }
            
            // Move up/down octave
            
            // Up arrow: move up one note
            Button(action: {
                midiEditorViewModel.moveHoverUp()
            }) {
                EmptyView()
            }
            .keyboardShortcut(.upArrow, modifiers: [])
            
            // Down arrow: move down one note
            Button(action: {
                midiEditorViewModel.moveHoverDown()
            }) {
                EmptyView()
            }
            .keyboardShortcut(.downArrow, modifiers: [])
            
            // Page Up: move up one octave
//            Button(action: {
//                midiEditorViewModel.goToNextOctaveUp()
//            }) {
//                EmptyView()
//            }
//            .keyboardShortcut(.pageUp, modifiers: [])
//            
//            // Page Down: move down one octave
//            Button(action: {
//                midiEditorViewModel.goToNextOctaveDown()
//            }) {
//                EmptyView()
//            }
//            .keyboardShortcut(.pageDown, modifiers: [])
        }
        .frame(width: 0, height: 0)
        .opacity(0)
    }
}

#Preview {
    KeyboardShortcutsBottomSection()
        .environmentObject(MidiEditorViewModel())
}
