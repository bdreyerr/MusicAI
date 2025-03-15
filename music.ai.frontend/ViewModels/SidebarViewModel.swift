import SwiftUI
import Combine
import Foundation

/// ViewModel for managing the sidebar state
class SidebarViewModel: ObservableObject {
    /// The list of all available library folders
    @Published var folders: [SidebarFolder] = SidebarFolder.allFolders
    
    /// The list of user-added folders
    @Published var userFolders: [UserFolder] = []
    
    /// The currently selected folder
    @Published var selectedFolder: SidebarFolder? = SidebarFolder.allFolders.first
    
    /// The currently selected user folder
    @Published var selectedUserFolder: UserFolder?
    
    /// Flag to track if we're currently loading folder contents
    @Published var isLoadingContents: Bool = false
    
    /// Error message if folder loading fails
    @Published var folderLoadError: String? = nil
    
    /// The items in the currently selected folder
    var selectedFolderItems: [FolderItem] {
        if let selectedFolder = selectedFolder {
            return selectedFolder.items
        } else if let selectedUserFolder = selectedUserFolder {
            // Return both subfolders and audio files, with subfolders first
            return selectedUserFolder.subfolders + selectedUserFolder.audioFiles
        }
        return []
    }
    
    /// Get the current path for display
    var currentFolderPath: String {
        guard let folder = selectedUserFolder else { return "" }
        
        let relativePath = folder.getRelativePath()
        if relativePath.isEmpty {
            return folder.name
        } else {
            return "\(folder.name) > \(relativePath)"
        }
    }
    
    /// Check if we can navigate back
    var canNavigateBack: Bool {
        return selectedUserFolder?.pathHistory.isEmpty == false
    }
    
    init() {
        loadUserFolders()
    }
    
    /// Select a library folder
    func selectFolder(_ folder: SidebarFolder) {
        selectedFolder = folder
        selectedUserFolder = nil
        folderLoadError = nil
    }
    
    /// Select a user folder
    func selectUserFolder(_ folder: UserFolder) {
        // Clear any previous errors
        folderLoadError = nil
        isLoadingContents = true
        
        // Set the selected folder
        selectedUserFolder = folder
        selectedFolder = nil
        
        // Start access to the security-scoped resource
        var didStartAccess = false
        if let bookmark = folder.bookmark {
            didStartAccess = bookmark.startAccessingSecurityScopedResource()
        }
        
        // Scan for audio files in the background
        DispatchQueue.global(qos: .userInitiated).async {
            folder.scanForAudioFiles()
            
            DispatchQueue.main.async {
                // Stop access to the security-scoped resource
                if didStartAccess {
                    folder.bookmark?.stopAccessingSecurityScopedResource()
                }
                
                self.isLoadingContents = false
                
                if folder.accessError != nil {
                    self.folderLoadError = "The folder could not be accessed. It may have been moved or deleted, or permission was denied."
                } else if folder.audioFiles.isEmpty && folder.subfolders.isEmpty {
                    // No error but also no files or folders found
                    self.folderLoadError = nil
                }
                
                // Force a UI update
                self.objectWillChange.send()
            }
        }
    }
    
    /// Navigate to a subfolder
    func navigateToSubfolder(_ item: FolderItem) {
        guard let path = item.metadata?["path"], 
              let type = item.metadata?["type"],
              type == "folder",
              let folder = selectedUserFolder else {
            return
        }
        
        isLoadingContents = true
        folderLoadError = nil
        
        // Start access to the security-scoped resource
        var didStartAccess = false
        if let bookmark = folder.bookmark {
            didStartAccess = bookmark.startAccessingSecurityScopedResource()
        }
        
        // Navigate to subfolder in the background
        DispatchQueue.global(qos: .userInitiated).async {
            folder.navigateToSubfolder(path)
            
            DispatchQueue.main.async {
                // Stop access to the security-scoped resource
                if didStartAccess {
                    folder.bookmark?.stopAccessingSecurityScopedResource()
                }
                
                self.isLoadingContents = false
                
                if folder.accessError != nil {
                    self.folderLoadError = "The subfolder could not be accessed. It may have been moved or deleted, or permission was denied."
                } else if folder.audioFiles.isEmpty && folder.subfolders.isEmpty {
                    // No error but also no files or folders found
                    self.folderLoadError = nil
                }
                
                // Force a UI update
                self.objectWillChange.send()
            }
        }
    }
    
    /// Navigate back to the previous folder
    func navigateBack() {
        guard let folder = selectedUserFolder else { return }
        
        isLoadingContents = true
        folderLoadError = nil
        
        // Start access to the security-scoped resource
        var didStartAccess = false
        if let bookmark = folder.bookmark {
            didStartAccess = bookmark.startAccessingSecurityScopedResource()
        }
        
        // Navigate back in the background
        DispatchQueue.global(qos: .userInitiated).async {
            let success = folder.navigateBack()
            
            DispatchQueue.main.async {
                // Stop access to the security-scoped resource
                if didStartAccess {
                    folder.bookmark?.stopAccessingSecurityScopedResource()
                }
                
                self.isLoadingContents = false
                
                if !success {
                    self.folderLoadError = "Could not navigate back."
                } else if folder.accessError != nil {
                    self.folderLoadError = "The folder could not be accessed. It may have been moved or deleted, or permission was denied."
                } else if folder.audioFiles.isEmpty && folder.subfolders.isEmpty {
                    // No error but also no files or folders found
                    self.folderLoadError = nil
                }
                
                // Force a UI update
                self.objectWillChange.send()
            }
        }
    }
    
    /// Navigate to the root folder
    func navigateToRoot() {
        guard let folder = selectedUserFolder else { return }
        
        isLoadingContents = true
        folderLoadError = nil
        
        // Start access to the security-scoped resource
        var didStartAccess = false
        if let bookmark = folder.bookmark {
            didStartAccess = bookmark.startAccessingSecurityScopedResource()
        }
        
        // Navigate to root in the background
        DispatchQueue.global(qos: .userInitiated).async {
            folder.navigateToRoot()
            
            DispatchQueue.main.async {
                // Stop access to the security-scoped resource
                if didStartAccess {
                    folder.bookmark?.stopAccessingSecurityScopedResource()
                }
                
                self.isLoadingContents = false
                
                if folder.accessError != nil {
                    self.folderLoadError = "The folder could not be accessed. It may have been moved or deleted, or permission was denied."
                } else if folder.audioFiles.isEmpty && folder.subfolders.isEmpty {
                    // No error but also no files or folders found
                    self.folderLoadError = nil
                }
                
                // Force a UI update
                self.objectWillChange.send()
            }
        }
    }
    
    /// Add a new folder from disk
    func addFolderFromDisk() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Select a folder containing audio files"
        openPanel.showsResizeIndicator = true
        openPanel.showsHiddenFiles = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseFiles = false
        
        if openPanel.runModal() == .OK {
            guard let url = openPanel.url else { return }
            
            // Create security-scoped bookmark
            do {
                let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                
                // Create a new user folder with the bookmark
                let newFolder = UserFolder(url: url, bookmarkData: bookmarkData)
                
                // Add to the list
                userFolders.append(newFolder)
                
                // Save the updated list
                saveUserFolders()
                
                // Select the new folder (which will trigger scanning)
                selectUserFolder(newFolder)
                
            } catch {
                print("Failed to create bookmark for folder: \(error.localizedDescription)")
                
                // Still create the folder but without bookmark
                let newFolder = UserFolder(url: url)
                userFolders.append(newFolder)
                saveUserFolders()
                selectUserFolder(newFolder)
            }
        }
    }
    
    /// Remove a user folder
    func removeUserFolder(_ folder: UserFolder) {
        userFolders.removeAll { $0.id == folder.id }
        
        if selectedUserFolder?.id == folder.id {
            selectedUserFolder = nil
            selectedFolder = folders.first
            folderLoadError = nil
        }
        
        saveUserFolders()
    }
    
    /// Refresh the contents of the currently selected user folder
    func refreshCurrentFolder() {
        if let folder = selectedUserFolder {
            selectUserFolder(folder)
        }
    }
    
    /// Save user folders to UserDefaults
    private func saveUserFolders() {
        let folderData = userFolders.map { folder -> [String: Any] in
            var data: [String: Any] = [
                "id": folder.id.uuidString,
                "name": folder.name,
                "path": folder.url.path
            ]
            
            // Include bookmark data if available
            if let bookmarkData = folder.bookmarkData {
                data["bookmark"] = bookmarkData
            }
            
            return data
        }
        
        UserDefaults.standard.set(folderData, forKey: "userFolders")
    }
    
    /// Load user folders from UserDefaults
    private func loadUserFolders() {
        guard let folderData = UserDefaults.standard.array(forKey: "userFolders") as? [[String: Any]] else {
            return
        }
        
        userFolders = folderData.compactMap { data in
            guard let idString = data["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let name = data["name"] as? String,
                  let path = data["path"] as? String else {
                return nil
            }
            
            // Get bookmark data if available
            let bookmarkData = data["bookmark"] as? Data
            
            // Create URL from bookmark if possible, otherwise use path
            if let bookmarkData = bookmarkData {
                do {
                    var isStale = false
                    let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
                    
                    // Create folder with resolved URL and original bookmark data
                    return UserFolder(id: id, name: name, url: url, bookmarkData: bookmarkData)
                } catch {
                    print("Failed to resolve bookmark: \(error.localizedDescription)")
                    // Fall back to path-based URL
                }
            }
            
            // If bookmark resolution failed or wasn't available, use path
            let url = URL(fileURLWithPath: path)
            return UserFolder(id: id, name: name, url: url)
        }
    }
} 