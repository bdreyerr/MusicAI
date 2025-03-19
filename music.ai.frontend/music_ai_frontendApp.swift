//
//  music_ai_frontendApp.swift
//  music.ai.frontend
//
//  Created by Ben Dreyer on 3/12/25.
//

import SwiftUI
import AppKit

// Create a class to handle application lifecycle events
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        // Release all security-scoped bookmarks and perform cleanup
        // We don't save individual file bookmarks to prevent cluttering UserDefaults
        AudioDragDropViewModel.shared.releaseAllSecurityScopedResources()
        print("🧹 Application terminating: Cleaned up all security-scoped resources without saving individual file bookmarks")
    }
}

@main
struct music_ai_frontendApp: App {
    // Create a shared ThemeManager instance for the entire app
    @StateObject private var themeManager = ThemeManager()
    // Create a shared SidebarViewModel instance
    @StateObject private var sidebarViewModel = SidebarViewModel()
    // Create a shared AudioDragDropViewModel instance
    @StateObject private var audioDragDropViewModel = AudioDragDropViewModel.shared
    // Create a shared SettingsViewModel instance
    @StateObject private var settingsViewModel = SettingsViewModel()
    
    // Register the app delegate
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(themeManager)
                .environmentObject(sidebarViewModel)
                .environmentObject(audioDragDropViewModel)
                .onAppear {
                    // Apply theme to window
                    setupAppearance()
                }
                .onChange(of: themeManager.currentTheme) { _, newTheme in
                    // Update window appearance when theme changes
                    setupAppearance()
                }
        }
        .windowStyle(.hiddenTitleBar)
        
        // Add Settings window
        Settings {
            SettingsView(viewModel: settingsViewModel)
                .environmentObject(themeManager)
        }
    }
    
    // Configure the app's appearance based on the current theme
    private func setupAppearance() {
        // Set the appearance for the entire application
        NSApp.appearance = NSAppearance(named: themeManager.currentTheme == .dark ? 
                                       .darkAqua : .aqua)
        
        // Update window appearance
        for window in NSApp.windows {
            // Customize window background
            window.backgroundColor = themeManager.currentTheme == .dark ? 
                NSColor(Color(white: 0.2)) : NSColor(Color(white: 0.9))
        }
    }
}
