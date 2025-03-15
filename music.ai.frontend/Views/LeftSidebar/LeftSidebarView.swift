import SwiftUI

struct LeftSidebarView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var viewModel: SidebarViewModel
    @State private var sidebarWidth: CGFloat = 320
    @State private var isResizing = false
    
    // Calculate widths for the two sections with a minimum width for the left section
    private var leftSectionWidth: CGFloat {
        // Ensure left section has a minimum width of 140px to prevent text wrapping
        let minLeftWidth: CGFloat = 140
        let calculatedWidth = sidebarWidth * 0.45 - 3 // Slightly less than half to give more space to content
        return max(calculatedWidth, minLeftWidth)
    }
    
    private var rightSectionWidth: CGFloat {
        // Right section gets the remaining width
        return sidebarWidth - leftSectionWidth - 5.5 // Account for divider (0.5) and resize handle (5)
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Left section - Folder list
            FolderListView(viewModel: viewModel)
                .frame(width: leftSectionWidth)
            
            // Divider between sections - thinner now
            Rectangle()
                .fill(themeManager.secondaryBorderColor.opacity(0.5))
                .frame(width: 0.5)
            
            // Right section - Folder contents
            FolderContentView(viewModel: viewModel)
                .frame(width: rightSectionWidth)
            
            // Resizing handle
            Rectangle()
                .fill(Color.clear)
                .frame(width: 5)
                .contentShape(Rectangle())
//                .cursor(.resizeLeftRight)
                .onHover { hovering in
                    if hovering && !isResizing {
                        NSCursor.resizeLeftRight.push()
                    } else if !hovering && !isResizing {
                        NSCursor.pop()
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            isResizing = true
                            let newWidth = sidebarWidth + value.translation.width
                            // Increase minimum width to ensure text doesn't wrap
                            sidebarWidth = min(max(newWidth, 280), 500)
                        }
                        .onEnded { _ in
                            isResizing = false
                        }
                )
        }
        .frame(width: sidebarWidth)
        .background(themeManager.secondaryBackgroundColor)
        .border(themeManager.secondaryBorderColor, width: 0.5)
    }
}

#Preview {
    LeftSidebarView()
        .environmentObject(ThemeManager())
        .environmentObject(SidebarViewModel())
} 
