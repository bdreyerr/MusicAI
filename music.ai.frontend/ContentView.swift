//
//  ContentView.swift
//  music.ai.frontend
//
//  Created by Ben Dreyer on 3/12/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var projectViewModel = ProjectViewModel()
    @StateObject private var aiChatViewModel = AIChatViewModel()
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var sidebarViewModel: SidebarViewModel
    @EnvironmentObject var audioDragDropViewModel: AudioDragDropViewModel
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
                    .environmentObject(sidebarViewModel)
                    .environmentObject(audioDragDropViewModel)
                
                // Timeline view - using the new ClaudeTimeline
                TimelineView(projectViewModel: projectViewModel)
                    .environmentObject(themeManager)
                    .environmentObject(audioDragDropViewModel)
//                CoordinatedScrollView(projectViewModel: projectViewModel)
//                    .environmentObject(themeManager)
                
                // Right sidebar for AI chat
                RightSidebarView(projectViewModel: projectViewModel)
                    .environmentObject(themeManager)
                    .environmentObject(aiChatViewModel)
            }
            .onAppear {
                // Connect the AIChatViewModel to the ProjectViewModel
                aiChatViewModel.setProjectViewModel(projectViewModel)
            }
            
            // Bottom section for effects and instruments
            BottomSectionView(projectViewModel: projectViewModel)
                .environmentObject(themeManager)
        }
        .frame(minWidth: 1000, minHeight: 700)
        .background(themeManager.backgroundColor)
        .toolbarBackground(themeManager.secondaryBackgroundColor, for: .automatic)
        .toolbarBackground(.visible, for: .automatic)
    }
}

#Preview {
    let projectViewModel = ProjectViewModel()
    let aiChatViewModel = AIChatViewModel(projectViewModel: projectViewModel)
    
    return ContentView()
        .environmentObject(ThemeManager())
        .environmentObject(SidebarViewModel())
        .environmentObject(AudioDragDropViewModel.shared)
}
