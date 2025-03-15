import SwiftUI

/// View for displaying the list of folders in the sidebar
struct FolderListView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var viewModel: SidebarViewModel
    
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Library Section
                        Text("Library")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(themeManager.primaryTextColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Library folders
                        ForEach(viewModel.folders) { folder in
                            FolderRowView(
                                folder: folder,
                                isSelected: viewModel.selectedFolder?.id == folder.id
                            ) {
                                viewModel.selectFolder(folder)
                            }
                        }
                        
                        Divider()
                            .padding(.vertical, 8)
                            .padding(.horizontal, 8)
                        
                        // User Folders Section
                        HStack {
                            Text("Folders")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(themeManager.primaryTextColor)
                            
                            Spacer()
                            
                            Button(action: {
                                viewModel.addFolderFromDisk()
                            }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 12))
                                    .foregroundColor(themeManager.secondaryTextColor)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .help("Add folder from disk")
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // User folders
                        if viewModel.userFolders.isEmpty {
                            Text("No folders added")
                                .font(.system(size: 12))
                                .foregroundColor(themeManager.secondaryTextColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                        } else {
                            ForEach(viewModel.userFolders) { folder in
                                UserFolderRowView(
                                    folder: folder,
                                    isSelected: viewModel.selectedUserFolder?.id == folder.id,
                                    onSelect: {
                                        viewModel.selectUserFolder(folder)
                                    },
                                    onRemove: {
                                        viewModel.removeUserFolder(folder)
                                    }
                                )
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

/// A row for user-added folders with remove option
struct UserFolderRowView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let folder: UserFolder
    let isSelected: Bool
    let onSelect: () -> Void
    let onRemove: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "folder")
                .font(.system(size: 12))
                .foregroundColor(themeManager.secondaryTextColor)
                .frame(width: 16)
            
            Text(folder.name)
                .font(.system(size: 12))
                .foregroundColor(themeManager.primaryTextColor)
                .lineLimit(1)
                .truncationMode(.tail)
            
            Spacer(minLength: 4)
            
            if isHovering {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundColor(themeManager.secondaryTextColor)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Remove folder")
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .background(
            isSelected ? themeManager.tertiaryBackgroundColor :
                (isHovering ? (themeManager.currentTheme == .dark ? Color(white: 0.3) : Color(white: 0.9)) : 
                    themeManager.secondaryBackgroundColor)
        )
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            isHovering = hovering
        }
    }
} 