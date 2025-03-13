//
//  music_ai_frontendApp.swift
//  music.ai.frontend
//
//  Created by Ben Dreyer on 3/12/25.
//

import SwiftUI
import AppKit

@main
struct music_ai_frontendApp: App {
    // Create a shared ThemeManager instance for the entire app
    @StateObject private var themeManager = ThemeManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(themeManager)
                .onAppear {
                    // Apply theme to window
                    setupAppearance()
                }
                .onChange(of: themeManager.currentTheme) { _ in
                    // Update window appearance when theme changes
                    setupAppearance()
                }
        }
    }
    
    // Configure the app's appearance based on the current theme
    private func setupAppearance() {
        // Set the appearance for the entire application
        NSApp.appearance = NSAppearance(named: themeManager.currentTheme == .dark ? 
                                       .darkAqua : .aqua)
        
        // Update window appearance
        for window in NSApp.windows {
            window.backgroundColor = themeManager.currentTheme == .dark ? 
                NSColor(Color(white: 0.2)) : NSColor(Color(white: 0.9))
        }
    }
}
