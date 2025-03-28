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
    // Reference to the shared FileViewModel
    var fileViewModel: FileViewModel?
    
    func applicationWillTerminate(_ notification: Notification) {
        // Release all security-scoped bookmarks and perform cleanup
        // We don't save individual file bookmarks to prevent cluttering UserDefaults
        SampleDragDropViewModel.shared.releaseAllSecurityScopedResources()
        print("🧹 Application terminating: Cleaned up all security-scoped resources without saving individual file bookmarks")
    }
    
    // Handle file opening
    func application(_ application: NSApplication, open urls: [URL]) {
        print("🔔 APP DELEGATE: Received request to open files: \(urls)")
        
        // Handle only the first file for now
        guard let fileToOpen = urls.first else { return }
        
        // Check if the file is a Glitch project file (.gpf)
        if fileToOpen.pathExtension.lowercased() == "gpf" {
            print("🔔 APP DELEGATE: Opening Glitch project: \(fileToOpen.path)")
            
            // Check if fileViewModel is available
            guard let fileViewModel = fileViewModel else {
                print("❌ APP DELEGATE: FileViewModel not available")
                return
            }
            
            // Post a notification to check for unsaved changes first
            NotificationCenter.default.post(
                name: Notification.Name("OpenSpecificProject"), 
                object: nil,
                userInfo: ["url": fileToOpen]
            )
        }
    }
}

@main
struct music_ai_frontendApp: App {
    // Create a shared ThemeManager instance for the entire app
    @StateObject private var themeManager = ThemeManager()
    // Create a shared SidebarViewModel instance
    @StateObject private var sidebarViewModel = SidebarViewModel()
    // Create a shared AudioDragDropViewModel instance
    @StateObject private var audioDragDropViewModel = SampleDragDropViewModel.shared
    // Create a shared FileViewModel instance
    @StateObject private var fileViewModel = FileViewModel()
    // Use the shared SettingsViewModel instance
    @StateObject private var settingsViewModel = SettingsViewModel.shared
    
    // Register the app delegate
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(themeManager)
                .environmentObject(sidebarViewModel)
                .environmentObject(audioDragDropViewModel)
                .environmentObject(fileViewModel)
                .environmentObject(settingsViewModel)
                .onAppear {
                    // Set the fileViewModel reference in the app delegate
                    appDelegate.fileViewModel = fileViewModel
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
        
        .commands {
            // Menu commands
            CommandGroup(replacing: .appInfo) {
                Button("About Glitch") {
                    NSApplication.shared.orderFrontStandardAboutPanel(
                        options: [
                            NSApplication.AboutPanelOptionKey.credits: NSAttributedString(
                                string: "A digital audio workstation created with SwiftUI.",
                                attributes: [
                                    NSAttributedString.Key.font: NSFont.systemFont(ofSize: 11),
                                    NSAttributedString.Key.foregroundColor: NSColor.labelColor
                                ]
                            ),
                            NSApplication.AboutPanelOptionKey.version: "",
                            NSApplication.AboutPanelOptionKey.applicationName: "Glitch"
                        ]
                    )
                }
            }
            
            CommandGroup(replacing: .newItem) {
                // File Menu - New, Open, Save, Save As
                Button("New Project") {
                    NotificationCenter.default.post(name: Notification.Name("NewProject"), object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
                
                Button("Open Project...") {
                    NotificationCenter.default.post(name: Notification.Name("OpenProject"), object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
                
                Divider()
                
                Button("Save") {
                    NotificationCenter.default.post(name: Notification.Name("SaveProject"), object: nil)
                }
                .keyboardShortcut("s", modifiers: .command)
                
                Button("Save As...") {
                    NotificationCenter.default.post(name: Notification.Name("SaveProjectAs"), object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }
            
            // Add a File Menu for better organization
            CommandMenu("File") {
                Button("New Project") {
                    NotificationCenter.default.post(name: Notification.Name("NewProject"), object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
                
                Button("Open Project...") {
                    NotificationCenter.default.post(name: Notification.Name("OpenProject"), object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
                
                Divider()
                
                Button("Save") {
                    NotificationCenter.default.post(name: Notification.Name("SaveProject"), object: nil)
                }
                .keyboardShortcut("s", modifiers: .command)
                
                Button("Save As...") {
                    NotificationCenter.default.post(name: Notification.Name("SaveProjectAs"), object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                
                if !fileViewModel.recentProjects.isEmpty {
                    Divider()
                    
                    Menu("Open Recent") {
                        ForEach(fileViewModel.recentProjects.prefix(5), id: \.self) { url in
                            Button(url.deletingPathExtension().lastPathComponent) {
                                // Post notification with specific URL
                                NotificationCenter.default.post(
                                    name: Notification.Name("OpenSpecificProject"),
                                    object: nil,
                                    userInfo: ["url": url]
                                )
                            }
                        }
                        
                        if fileViewModel.recentProjects.count > 0 {
                            Divider()
                            Button("Clear Recent") {
                                fileViewModel.recentProjects = []
                                fileViewModel.saveRecentProjects()
                            }
                        }
                    }
                }
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
            // Customize window background
            window.backgroundColor = themeManager.currentTheme == .dark ? 
                NSColor(Color(white: 0.2)) : NSColor(Color(white: 0.9))
        }
    }
}
