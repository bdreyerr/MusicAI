//
//  NewTimelineView.swift
//  music.ai.frontend
//
//  Created by Ben Dreyer on 3/30/25.
//

import SwiftUI
import Combine
import AppKit

struct NewTimelineView: View {

    // --- Migrated State & ViewModels ---
    @ObservedObject var projectViewModel: ProjectViewModel
    @StateObject private var timelineState: TimelineStateViewModel
    @StateObject private var menuCoordinator = MenuCoordinator()
    @EnvironmentObject var themeManager: ThemeManager

    // --- Configuration ---
    let sidebarWidth: CGFloat = 200
    let rulerHeight: CGFloat = 25
    // let contentSize = CGSize(width: 800, height: 800) // Removed fixed content size

    // --- State for Scroll Offsets ---
    @State private var horizontalOffset: CGFloat = 0
    @State private var verticalOffset: CGFloat = 0

    // --- Coordinate Space Name ---
    private let scrollCoordinateSpace = "scroll"

    // --- Initializer ---
    init(projectViewModel: ProjectViewModel) {
        self.projectViewModel = projectViewModel
        // Initialize the timeline state with _StateObject wrapper
        _timelineState = StateObject(wrappedValue: TimelineStateViewModel(projectViewModel: projectViewModel))
    }

    var body: some View {
        // Use Grid for the 2x2 layout (iOS 16+/macOS 13+)
        Grid(alignment: .topLeading, horizontalSpacing: 0, verticalSpacing: 0) {
            // --- Row 1: Top-Left Corner and Ruler ---
            GridRow {
                // Top-Left Corner (Fixed)
                TopLeftCornerView()
                    .frame(width: sidebarWidth, height: rulerHeight)
                    .border(Color.gray.opacity(0.5)) // Visual guide

                // Ruler Container (Clips content, scrolls horizontally via offset)
                // Pass geometry width for dynamic sizing later
                GeometryReader { geo in
                    RulerView(availableWidth: geo.size.width, currentOffset: horizontalOffset)
                }
                .frame(height: rulerHeight)
                .clipped() // Important: Clips the offset content
                .border(Color.gray.opacity(0.5)) // Visual guide
            } // End GridRow 1

            // --- Row 2: Sidebar and Main Content ---
            GridRow {
                // Sidebar Container (Clips content, scrolls vertically via offset)
                // Pass geometry height for dynamic sizing later
                GeometryReader { geo in
                    SidebarView(availableHeight: geo.size.height, currentOffset: verticalOffset)
                }
                .frame(width: sidebarWidth)
                .clipped() // Important: Clips the offset content
                .border(Color.gray.opacity(0.5)) // Visual guide

                // Main Scrollable Content Area
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    ZStack(alignment: .topLeading) { // Use ZStack for easy placement of content + tracker
                        // The actual scrollable content - let it determine its own size for now
                        MainContentView()

                        // GeometryReader for tracking scroll offset
                        GeometryReader { geometry in
                            Color.clear // Invisible view to track position
                                .preference(key: ScrollOffsetPreferenceKey.self,
                                            value: geometry.frame(in: .named(scrollCoordinateSpace)).origin)
                        }
                    }
                }
                .coordinateSpace(name: scrollCoordinateSpace) // Define the coordinate space for the ScrollView
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                    // Update state variables when preference changes
                    // Negate the offset because the origin moves opposite to scroll direction
                    self.horizontalOffset = -offset.x
                    self.verticalOffset = -offset.y
                }
                .border(Color.gray.opacity(0.5)) // Visual guide

            } // End GridRow 2
        } // End Grid
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Make grid fill available space
        .environmentObject(menuCoordinator) // Add menuCoordinator to environment
    }
}

// --- PreferenceKey for passing scroll offset ---
//struct ScrollOffsetPreferenceKey: PreferenceKey {
//    static var defaultValue: CGPoint = .zero
//    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {
//        // Use the first reported value ( ZStack ensures only one GeometryReader reports)
//        value = nextValue()
//    }
//}


// --- Placeholder Views ---

struct TopLeftCornerView: View {
    var body: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.1))
            .overlay(Text("Fixed").font(.caption))
    }
}

struct RulerView: View {
    // let contentWidth: CGFloat // Use availableWidth instead
    let availableWidth: CGFloat
    let currentOffset: CGFloat

    var body: some View {
        // The actual ruler content (can be complex) - Use a placeholder width for now
        let placeholderContentWidth: CGFloat = 2000
        HStack(spacing: 50) {
            ForEach(0..<Int(placeholderContentWidth/100), id: \.self) { i in
                VStack {
                    Text("\(i * 100)")
                        .font(.caption)
                    Rectangle().fill(Color.black).frame(width: 1, height: 10)
                }
                .frame(width: 50) // Ensure consistent spacing
            }
        }
        .frame(width: placeholderContentWidth, alignment: .leading) // Make content wide
        .background(Color.orange.opacity(0.1))
        // Apply the horizontal offset based on main scroll view's position
        .offset(x: -currentOffset)
        // Add animation for smoother visual updates (optional)
        // .animation(.easeOut(duration: 0.1), value: currentOffset)
    }
}

struct SidebarView: View {
    // let contentHeight: CGFloat // Use availableHeight instead
    let availableHeight: CGFloat
    let currentOffset: CGFloat

    var body: some View {
        // The actual sidebar content (can be complex) - Use a placeholder height for now
        let placeholderContentHeight: CGFloat = 1500
        VStack(alignment: .leading, spacing: 20) {
            ForEach(0..<Int(placeholderContentHeight/50), id: \.self) { i in
                Text("Item \(i)")
                    .padding(.leading, 5)
                    .frame(height: 30)
                    .background(Color.cyan.opacity( i % 2 == 0 ? 0.2 : 0.1))
            }
        }
        .frame(height: placeholderContentHeight, alignment: .top) // Make content tall
        .background(Color.blue.opacity(0.1))
        // Apply the vertical offset based on main scroll view's position
        .offset(y: -currentOffset)
         // Add animation for smoother visual updates (optional)
        // .animation(.easeOut(duration: 0.1), value: currentOffset)
    }
}

struct MainContentView: View {
    // let size: CGSize // Removed size dependency for now
    var body: some View {
        // Your main complex content goes here (e.g., graphs, timeline bars)
        // Use placeholder dimensions until real content is added
        let placeholderWidth: CGFloat = 2000
        let placeholderHeight: CGFloat = 1500
        ZStack {
            Rectangle()
                .fill(Color.green.opacity(0.1))
            Text("Scrollable Content\n(Placeholder Size)")
                .multilineTextAlignment(.center)

            // Example content alignment guides
             VStack{
                 Spacer()
                 HStack{Spacer()}
             }
             .border(Color.red)

        }
        .frame(width: placeholderWidth, height: placeholderHeight) // Use placeholder size
    }
}
