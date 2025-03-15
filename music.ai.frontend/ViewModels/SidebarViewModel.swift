import SwiftUI
import Combine

/// ViewModel for managing the sidebar state
class SidebarViewModel: ObservableObject {
    /// The list of all available folders
    @Published var folders: [SidebarFolder] = SidebarFolder.allFolders
    
    /// The currently selected folder
    @Published var selectedFolder: SidebarFolder? = SidebarFolder.allFolders.first
    
    /// The items in the currently selected folder
    var selectedFolderItems: [FolderItem] {
        selectedFolder?.items ?? []
    }
    
    /// Select a folder by its name
    func selectFolder(_ folder: SidebarFolder) {
        selectedFolder = folder
    }
} 