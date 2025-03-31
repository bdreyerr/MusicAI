////
////  NewTimelineView.swift
////  music.ai.frontend
////
////  Created by Ben Dreyer on 3/30/25.
////
//
//import SwiftUI
//import Combine
//import AppKit
//
//struct NewTimelineView: View {
//
//    // --- Migrated State & ViewModels ---
//    @ObservedObject var projectViewModel: ProjectViewModel
//    @StateObject private var timelineState: TimelineStateViewModel
//    @StateObject private var menuCoordinator = MenuCoordinator()
//    @EnvironmentObject var themeManager: ThemeManager
//
//    // --- Configuration ---
//    let sidebarWidth: CGFloat = 200
//    let rulerHeight: CGFloat = 25
//    // let contentSize = CGSize(width: 800, height: 800) // Removed fixed content size
//
//    // --- State for Scroll Offsets ---
//    @State private var horizontalOffset: CGFloat = 0
//    @State private var verticalOffset: CGFloat = 0
//
//    // --- Coordinate Space Name ---
//    private let scrollCoordinateSpace = "scroll"
//
//    // --- Initializer ---
//    init(projectViewModel: ProjectViewModel) {
//        self.projectViewModel = projectViewModel
//        // Initialize the timeline state with _StateObject wrapper
//        _timelineState = StateObject(wrappedValue: TimelineStateViewModel(projectViewModel: projectViewModel))
//    }
//
//    var body: some View {
//        ZStack {
//            TimelineButtons(projectViewModel: projectViewModel, timelineState: timelineState)
//            
//            
//            // Wrap the Grid in GeometryReader to get total available size
//            GeometryReader { geometry in
//                let mainContentWidth = max(0, geometry.size.width - sidebarWidth) // Calculate width for main area
//                
//                // Use Grid for the 2x2 layout (iOS 16+/macOS 13+)
//                Grid(alignment: .topLeading, horizontalSpacing: 0, verticalSpacing: 0) {
//                    // --- Row 1: Top-Left Corner and Ruler ---
//                    GridRow {
//                        // Top-Left Corner (Fixed)
//                        TopLeftCornerView()
//                            .frame(width: sidebarWidth, height: rulerHeight)
//                            .border(Color.gray.opacity(0.5)) // Visual guide
//                        
//                        // Ruler Container (Clips content, scrolls horizontally via offset)
//                        GeometryReader { geo in
//                            RulerView(
//                                projectViewModel: projectViewModel,
//                                timelineState: timelineState,
//                                availableWidth: geo.size.width,
//                                currentOffset: horizontalOffset
//                            )
//                        }
//                        .frame(height: rulerHeight)
//                        .clipped() // Important: Clips the offset content
//                        .border(Color.gray.opacity(0.5)) // Visual guide
//                    } // End GridRow 1
//                    
//                    // --- Row 2: Sidebar and Main Content ---
//                    GridRow {
//                        // Sidebar Container (Clips content, scrolls vertically via offset)
//                        GeometryReader { geo in
//                            SidebarView(
//                                projectViewModel: projectViewModel,
//                                menuCoordinator: menuCoordinator,
//                                sidebarWidth: sidebarWidth,
//                                availableHeight: geo.size.height,
//                                currentOffset: verticalOffset
//                            )
//                        }
//                        .frame(width: sidebarWidth)
//                        .clipped() // Important: Clips the offset content
//                        .border(Color.gray.opacity(0.5)) // Visual guide
//                        
//                        // Main Scrollable Content Area
//                        ScrollView([.horizontal, .vertical], showsIndicators: true) {
//                            ZStack(alignment: .topLeading) { // Use ZStack for easy placement of content + tracker
//                                // The actual scrollable content
//                                MainContentView(
//                                    projectViewModel: projectViewModel,
//                                    timelineState: timelineState,
//                                    width: mainContentWidth // Pass the calculated width
//                                )
//                                
//                                // GeometryReader for tracking scroll offset
//                                GeometryReader { geometry in
//                                    Color.clear // Invisible view to track position
//                                        .preference(key: ScrollOffsetPreferenceKey.self,
//                                                    value: geometry.frame(in: .named(scrollCoordinateSpace)).origin)
//                                }
//                            }
//                        }
//                        .coordinateSpace(name: scrollCoordinateSpace) // Define the coordinate space for the ScrollView
//                        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
//                            // Update state variables when preference changes
//                            // Negate the offset because the origin moves opposite to scroll direction
//                            self.horizontalOffset = -offset.x
//                            self.verticalOffset = -offset.y
//                        }
//                        .border(Color.gray.opacity(0.5)) // Visual guide
//                        
//                    } // End GridRow 2
//                } // End Grid
//                .frame(maxWidth: .infinity, maxHeight: .infinity) // Make grid fill available space
//            }
//            // Environment objects and onAppear moved outside the GeometryReader
//            .environmentObject(menuCoordinator)
//            .onAppear {
//                DispatchQueue.main.async {
//                    menuCoordinator.projectViewModel = projectViewModel
//                    // We might need to add other connections here later as we migrate more features
//                }
//            }
//        }
//    }
//}
//
//// --- PreferenceKey for passing scroll offset ---
////struct ScrollOffsetPreferenceKey: PreferenceKey {
////    static var defaultValue: CGPoint = .zero
////    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {
////        // Use the first reported value ( ZStack ensures only one GeometryReader reports)
////        value = nextValue()
////    }
////}
//
//
//// --- Placeholder Views ---
//
//struct TopLeftCornerView: View {
//    var body: some View {
//        Rectangle()
//            .fill(Color.gray.opacity(0.1))
//            .overlay(Text("Fixed").font(.caption))
//    }
//}
//
//struct RulerView: View {
//    // --- Dependencies ---
//    @ObservedObject var projectViewModel: ProjectViewModel
//    @ObservedObject var timelineState: TimelineStateViewModel
//    @EnvironmentObject var themeManager: ThemeManager
//
//    // --- Layout & Scrolling ---
//    let availableWidth: CGFloat
//    let currentOffset: CGFloat
//    let rulerHeight: CGFloat = 25 // Define rulerHeight locally or pass it in
//
//    // Calculate content width based on state and available view width
//    private var contentWidth: CGFloat {
//        max(
//            timelineState.calculateContentWidth(
//                viewWidth: availableWidth, // Use the width provided by GeometryReader
//                timeSignatureBeats: projectViewModel.timeSignatureBeats,
//                tracks: projectViewModel.tracks // Pass tracks if needed by calculation
//            ),
//            availableWidth // Ensure minimum width is the visible area
//        )
//    }
//
//    var body: some View {
//        // Replace placeholder with actual TimelineRuler and overlays
//        TimelineRuler(
//            state: timelineState,
//            projectViewModel: projectViewModel,
//            width: contentWidth, // Use calculated width
//            height: rulerHeight   // Use defined height
//        )
//        .environmentObject(themeManager)
//        .overlay(
//            TimelineRulerSelectionIndicator(
//                state: timelineState,
//                projectViewModel: projectViewModel,
//                height: rulerHeight
//            )
//            .environmentObject(themeManager)
//        )
//        // Re-add the PlayheadIndicator overlay
//        .overlay(
//            PlayheadIndicator(
//                currentBeat: projectViewModel.currentBeat,
//                state: timelineState,
//                projectViewModel: projectViewModel
//            )
//            .environmentObject(themeManager)
//            .frame(height: rulerHeight)
//        )
//        // Re-add necessary modifiers that were removed
//        .frame(width: contentWidth, height: rulerHeight) // Set frame for the ruler content itself
//        .background(themeManager.rulerBackgroundColor)
//        // Apply the horizontal offset based on main scroll view's position
//        .offset(x: -currentOffset)
//    }
//}
//
//struct SidebarView: View {
//    // --- Dependencies ---
//    @ObservedObject var projectViewModel: ProjectViewModel
//    @ObservedObject var menuCoordinator: MenuCoordinator
//    @EnvironmentObject var themeManager: ThemeManager
//
//    // --- Layout & Scrolling ---
//    let sidebarWidth: CGFloat
//    let availableHeight: CGFloat
//    let currentOffset: CGFloat
//
//    var body: some View {
//        // Use the actual Track Controls layout from TimelineView
//        VStack(alignment: .leading, spacing: 0) {
//            // Track controls
//            ForEach(projectViewModel.tracks) { track in
//                TrackControlsView(
//                    track: track,
//                    projectViewModel: projectViewModel
//                )
//                .environmentObject(themeManager)
//                .frame(width: sidebarWidth) // Now uses the passed sidebarWidth
//            }
//            
//            // Add track button
//            Button(action: showAddTrackMenu) {
//                HStack {
//                    Image(systemName: "plus.circle.fill")
//                        .foregroundColor(themeManager.primaryTextColor)
//                    Text("Add Track")
//                        .foregroundColor(themeManager.primaryTextColor)
//                }
//                .padding(8)
//                .frame(width: sidebarWidth, alignment: .leading) // Now uses the passed sidebarWidth
//            }
//            .buttonStyle(BorderlessButtonStyle())
//            .background(themeManager.secondaryBackgroundColor.opacity(0.3))
//            .padding(.top, 4)
//            
//            Spacer() // Pushes content to the top
//        }
//        // Frame height calculation might need adjustment based on actual content height
//        // For now, let it grow based on track count. We might need a totalHeight calculation later.
//        // .frame(height: placeholderContentHeight, alignment: .top) // Remove placeholder height
//        .background(themeManager.backgroundColor) // Use theme background
//         // Add animation for smoother visual updates (optional)
//        // .animation(.easeOut(duration: 0.1), value: currentOffset)
//    }
//    
//    // Show a menu to add different track types (copied from TimelineView)
//    private func showAddTrackMenu() {
//        let menu = NSMenu(title: "Add Track")
//        
//        // Use our coordinator for the selectors
//        menu.addItem(withTitle: "Audio Track", action: #selector(MenuCoordinator.addAudioTrack), keyEquivalent: "t")
//            .target = menuCoordinator
//        
//        menu.addItem(withTitle: "MIDI Track", action: #selector(MenuCoordinator.addMidiTrack), keyEquivalent: "T")
//            .target = menuCoordinator
//        
//        if let event = NSApplication.shared.currentEvent,
//           let contentView = NSApp.mainWindow?.contentView {
//            NSMenu.popUpContextMenu(menu, with: event, for: contentView)
//        }
//    }
//}
//
//struct MainContentView: View {
//    // --- Dependencies ---
//    @ObservedObject var projectViewModel: ProjectViewModel
//    @ObservedObject var timelineState: TimelineStateViewModel
//    @EnvironmentObject var themeManager: ThemeManager
//    
//    // --- Layout ---
//    let width: CGFloat // Width passed down from parent context
//
//    var body: some View {
//        // Replace placeholder with the actual SharedTracksGridContainer
//        SharedTracksGridContainer(
//            projectViewModel: projectViewModel,
//            state: timelineState,
//            width: width // Use the passed width
//        )
//        .environmentObject(themeManager)
//        // Frame the container with the calculated width.
//        // Height will be determined intrinsically by the container.
//        .frame(width: width)
//        // Add relevant IDs for updates if needed (copied from TimelineView)
//        .id("shared-tracks-container-\(themeManager.themeChangeIdentifier)-\(timelineState.contentSizeChangeId)")
//
//        // Remove the placeholder ZStack and frame
//        /*
//        let placeholderWidth: CGFloat = 2000
//        let placeholderHeight: CGFloat = 1500
//        ZStack {
//            Rectangle()
//                .fill(Color.green.opacity(0.1))
//            Text("Scrollable Content\n(Placeholder Size)")
//                .multilineTextAlignment(.center)
//
//            // Example content alignment guides
//             VStack{
//                 Spacer()
//                 HStack{Spacer()}
//             }
//             .border(Color.red)
//
//        }
//        .frame(width: placeholderWidth, height: placeholderHeight) // Use placeholder size
//        */
//    }
//}
