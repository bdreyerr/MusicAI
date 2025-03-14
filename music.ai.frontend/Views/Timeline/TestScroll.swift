import SwiftUI

struct CoordinatedScrollView: View {
    
    @StateObject private var timelineState = TimelineState()
    @State private var startDragY: CGFloat = 0
    @State private var isDragging: Bool = false
    @StateObject private var menuCoordinator = MenuCoordinator()
    @ObservedObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var themeManager: ThemeManager
    // Constants
    let rulerHeight: CGFloat = 25
    let trackHeight: CGFloat = 70
    let controlsWidth: CGFloat = 200 // Must match TrackView.controlsWidth
    
    // Scroll position state
    @State private var horizontalScrollOffset: CGFloat = 0
    @State private var verticalScrollOffset: CGFloat = 0
    
    // ScrollViewProxy references for programmatic scrolling
    @State private var topProxy: ScrollViewProxy? = nil
    @State private var leftProxy: ScrollViewProxy? = nil
    
    // Initialize with project view model
        init(projectViewModel: ProjectViewModel) {
            self.projectViewModel = projectViewModel
        }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top section - non-scrollable, updates with middle horizontal scroll
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(0..<20) { i in
                            Rectangle()
                                .fill(Color.blue.opacity(0.3))
                                .frame(width: 100, height: 80)
                                .overlay(Text("Top \(i)"))
                                .id("top\(i)")
                        }
                    }
                }
                .disabled(true) // Disable scrolling
                .onAppear {
                    topProxy = proxy
                }
            }
            
            HStack(spacing: 0) {
                // Left section - non-scrollable, updates with middle vertical scroll
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            ForEach(0..<20) { i in
                                Rectangle()
                                    .fill(Color.green.opacity(0.3))
                                    .frame(width: 80, height: 100)
                                    .overlay(Text("Left \(i)"))
                                    .id("left\(i)")
                            }
                        }
                    }
                    .disabled(true) // Disable scrolling
                    .onAppear {
                        leftProxy = proxy
                    }
                }
                
                // Middle section - scrollable in both directions
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    VStack(spacing: 0) {
                        ForEach(0..<20) { row in
                            HStack(spacing: 0) {
                                ForEach(0..<20) { col in
                                    Rectangle()
                                        .fill(Color.purple.opacity(0.2))
                                        .frame(width: 100, height: 100)
                                        .overlay(Text("[\(col),\(row)]"))
                                        .id("cell\(col)_\(row)")
                                }
                            }
                        }
                    }
                    .background(
                        GeometryReader { geo -> Color in
                            let horizontalOffset = geo.frame(in: .named("middleScroll")).minX
                            let verticalOffset = geo.frame(in: .named("middleScroll")).minY
                            
                            // When middle is scrolled horizontally, update top
                            if abs(horizontalOffset - horizontalScrollOffset) > 1 {
                                DispatchQueue.main.async {
                                    horizontalScrollOffset = horizontalOffset
                                    
                                    // Calculate the index based on the offset
                                    let index = Int(-horizontalOffset/100)
                                    // Make sure index is within bounds
                                    let safeIndex = max(0, min(19, index))
                                    
                                    topProxy?.scrollTo("top\(safeIndex)", anchor: .leading)
                                }
                            }
                            
                            // When middle is scrolled vertically, update left
                            if abs(verticalOffset - verticalScrollOffset) > 1 {
                                DispatchQueue.main.async {
                                    verticalScrollOffset = verticalOffset
                                    
                                    // Calculate the index based on the offset
                                    let index = Int(-verticalOffset/100)
                                    // Make sure index is within bounds
                                    let safeIndex = max(0, min(19, index))
                                    
                                    leftProxy?.scrollTo("left\(safeIndex)", anchor: .top)
                                }
                            }
                            
                            return Color.clear
                        }
                    )
                }
                .coordinateSpace(name: "middleScroll")
            }
        }
    }
}
