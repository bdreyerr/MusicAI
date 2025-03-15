import SwiftUI

/// View for displaying the list of folders in the sidebar
struct FolderListView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var viewModel: SidebarViewModel
    
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 0) {
                // Header
                Text("Library")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(themeManager.primaryTextColor)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(themeManager.secondaryBackgroundColor)
                
                // Custom scrollable list of folders without separators
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(viewModel.folders) { folder in
                            FolderRowView(folder: folder, isSelected: viewModel.selectedFolder?.id == folder.id) {
                                viewModel.selectFolder(folder)
                            }
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

/// A single row in the folder list with hover effects
struct FolderRowView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let folder: SidebarFolder
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: folder.icon)
                .font(.system(size: 12))
                .foregroundColor(themeManager.secondaryTextColor)
                .frame(width: 16)
            Text(folder.name)
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
            backgroundForState()
        )
        .onTapGesture {
            onTap()
        }
        .onHover { hovering in
            isHovering = hovering
        }
    }
    
    private func backgroundForState() -> Color {
        if isSelected {
            return themeManager.tertiaryBackgroundColor
        } else if isHovering {
            return themeManager.currentTheme == .dark ? 
                Color(white: 0.3) : Color(white: 0.9)
        } else {
            return themeManager.secondaryBackgroundColor
        }
    }
} 