import SwiftUI

struct LeftSidebarView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var viewModel: SidebarViewModel
    @State private var sidebarWidth: CGFloat = 320
    @State private var isResizing = false
    
    // Calculate widths for the two sections
    private var leftSectionWidth: CGFloat = 60 // Fixed width for icon column with logo
    
    private var rightSectionWidth: CGFloat {
        // Right section gets the remaining width
        return sidebarWidth - leftSectionWidth - 0.5 // Account for divider (0.5)
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Left section - Folder list
            FolderListView(viewModel: viewModel)
                .frame(width: leftSectionWidth)
            
            // Divider between sections
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
                            // Adjust minimum width to account for new icon-only left section
                            sidebarWidth = min(max(newWidth, 220), 500) // Adjusted minimum width
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
