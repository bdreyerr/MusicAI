import SwiftUI

/// View for displaying the contents of a selected folder
struct FolderContentView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var viewModel: SidebarViewModel
    
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 0) {
                // Header showing the selected folder name
                // if let selectedFolder = viewModel.selectedFolder {
                //     HStack(spacing: 6) {
                //         Image(systemName: selectedFolder.icon)
                //             .font(.system(size: 12))
                //             .frame(width: 16)
                //         Text(selectedFolder.name)
                //             .font(.subheadline)
                //             .fontWeight(.medium)
                //             .lineLimit(1)
                //             .truncationMode(.tail)
                //         Spacer(minLength: 4)
                //     }
                //     .foregroundColor(themeManager.primaryTextColor)
                //     .padding(.horizontal, 8)
                //     .padding(.vertical, 8)
                //     .frame(maxWidth: .infinity, alignment: .leading)
                //     .background(themeManager.tertiaryBackgroundColor)
                // }
                
                // Custom scrollable list of items without separators
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(viewModel.selectedFolderItems) { item in
                            FolderItemRowView(item: item)
                        }
                    }
                }
                .background(themeManager.secondaryBackgroundColor)
            }
            .frame(width: geometry.size.width)
            .background(themeManager.secondaryBackgroundColor)
            .border(themeManager.secondaryBorderColor, width: 0.5)
        }
    }
}

/// A single row in the folder content list with hover effects
struct FolderItemRowView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let item: FolderItem
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: item.icon)
                .font(.system(size: 12))
                .foregroundColor(themeManager.secondaryTextColor)
                .frame(width: 16)
            Text(item.name)
                .font(.system(size: 12))
                .foregroundColor(themeManager.primaryTextColor)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 4)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .background(
            isHovering ?
            (themeManager.currentTheme == .dark ? Color(white: 0.3) : Color(white: 0.9)) :
            themeManager.secondaryBackgroundColor
        )
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            // Handle item selection if needed
        }
    }
} 