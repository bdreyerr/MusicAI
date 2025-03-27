import SwiftUI

/// View for displaying the list of folders in the sidebar
struct FolderListView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var viewModel: SidebarViewModel
    
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .center, spacing: 0) {
                // Logo Section
                Image("logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .cornerRadius(20)
                    .padding(.vertical, 14)
                
                Divider()
                    .frame(height: 0.5)
                    .background(themeManager.secondaryBorderColor)
                
                // Library folders - icons only
                VStack(spacing: 8) {
                    ForEach(viewModel.folders) { folder in
                        IconRowView(
                            folder: folder,
                            isSelected: viewModel.selectedFolder?.id == folder.id
                        ) {
                            viewModel.selectFolder(folder)
                        }
                    }
                }
                .padding(.top, 12)
                
                Spacer()
            }
            .frame(width: 60)
            .background(themeManager.secondaryBackgroundColor)
            .border(themeManager.secondaryBorderColor, width: 0.5)
        }
    }
}

/// A single icon in the folder list with hover effects
struct IconRowView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let folder: SidebarFolder
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Image(systemName: folder.icon)
            .font(.system(size: 18))
            .foregroundColor(foregroundColor)
            .frame(width: 32, height: 32)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }
            .onHover { hovering in
                isHovering = hovering
            }
    }
    
    private var foregroundColor: Color {
        if isSelected {
            return themeManager.accentColor
        } else if isHovering {
            return themeManager.primaryTextColor
        } else {
            return themeManager.secondaryTextColor
        }
    }
}

#Preview {
    FolderListView(viewModel: SidebarViewModel())
        .environmentObject(ThemeManager())
} 
