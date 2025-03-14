//
//  ContentView.swift
//  music.ai.frontend
//
//  Created by Ben Dreyer on 3/12/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var projectViewModel = ProjectViewModel()
    @StateObject private var themeManager = ThemeManager()
    @State private var showThemeSettings = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Top control bar
            TopControlBarView(projectViewModel: projectViewModel)
                .environmentObject(themeManager)
            
            // Main content area
            HStack(spacing: 0) {
                // Left sidebar - using the one from Views/LeftSidebar folder
                LeftSidebarView()
                    .environmentObject(themeManager)
                
                // Timeline view - using the new ClaudeTimeline
                TimelineView(projectViewModel: projectViewModel)
                    .environmentObject(themeManager)
//                CoordinatedScrollView(projectViewModel: projectViewModel)
//                    .environmentObject(themeManager)
            }
        }
        .frame(minWidth: 1000, minHeight: 700)
        .background(themeManager.backgroundColor)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    showThemeSettings.toggle()
                }) {
                    Label("Theme", systemImage: "paintpalette")
                        .foregroundColor(themeManager.primaryTextColor)
                }
                .help("Change application theme")
                .popover(isPresented: $showThemeSettings) {
                    ThemeSettingsView()
                        .environmentObject(themeManager)
                }
            }
        }
        .toolbarBackground(themeManager.secondaryBackgroundColor, for: .automatic)
        .toolbarBackground(.visible, for: .automatic)
        .environmentObject(themeManager)
    }
}

#Preview {
    ContentView()
}
