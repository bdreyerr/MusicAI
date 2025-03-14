import SwiftUI
import AppKit

/// Main container view for the bottom section of the application
struct BottomSectionView: View {
    @ObservedObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isExpanded: Bool = true
    
    // State for resizing
    @State private var sectionHeight: CGFloat = 200 // Increased default height
    @State private var isHoveringResizeArea: Bool = false
    @State private var isDraggingResize: Bool = false
    @State private var dragStartY: CGFloat = 0
    @State private var dragStartHeight: CGFloat = 0
    
    // Minimum heights
    private let collapsedHeight: CGFloat = 40
    private let minExpandedHeight: CGFloat = 160
    private let maxExpandedHeight: CGFloat = 400
    private let resizeAreaHeight: CGFloat = 8
    
    var body: some View {
        VStack(spacing: 0) {
            // Resize handle area at the top
            Rectangle()
                .fill(Color.clear)
                .frame(height: resizeAreaHeight)
                .background(isHoveringResizeArea ? themeManager.tertiaryBackgroundColor.opacity(0.5) : Color.clear)
                .onHover { hovering in
                    isHoveringResizeArea = hovering
                    if hovering {
                        NSCursor.resizeUpDown.set()
                    } else if !isDraggingResize {
                        NSCursor.arrow.set()
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isDraggingResize {
                                isDraggingResize = true
                                dragStartY = value.startLocation.y
                                dragStartHeight = sectionHeight
                                NSCursor.resizeUpDown.set()
                            }
                            
                            // Calculate new height (drag up = increase height)
                            let dragDelta = dragStartY - value.location.y
                            let newHeight = max(minExpandedHeight, min(maxExpandedHeight, dragStartHeight + dragDelta))
                            sectionHeight = newHeight
                        }
                        .onEnded { _ in
                            isDraggingResize = false
                            if !isHoveringResizeArea {
                                NSCursor.arrow.set()
                            }
                        }
                )
                .zIndex(1) // Ensure resize handle is above other content
            
            // Header bar with toggle
            HStack {
                Text("Track Inspector")
                    .font(.headline)
                    .foregroundColor(themeManager.primaryTextColor)
                
                Spacer()
                
                // Toggle to expand/collapse the bottom section
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                        .foregroundColor(themeManager.primaryTextColor)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(BorderlessButtonStyle())
                .help(isExpanded ? "Collapse" : "Expand")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(themeManager.tertiaryBackgroundColor)
            .border(themeManager.secondaryBorderColor, width: 0.5)
            
            // Content area - only shown when expanded
            if isExpanded {
                // Directly embed the EffectsRackView instead of using TabView
                EffectsRackView(projectViewModel: projectViewModel)
                    .frame(height: sectionHeight - collapsedHeight) // Adjust height based on section height
            }
        }
        .frame(height: isExpanded ? sectionHeight : collapsedHeight)
        .background(themeManager.secondaryBackgroundColor)
        .overlay(
            // Top border
            Rectangle()
                .fill(themeManager.secondaryBorderColor)
                .frame(height: 0.5)
                .offset(y: -0.25),
            alignment: .top
        )
    }
}

#Preview {
    BottomSectionView(projectViewModel: ProjectViewModel())
        .environmentObject(ThemeManager())
} 