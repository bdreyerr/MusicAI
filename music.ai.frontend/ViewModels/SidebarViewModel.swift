import SwiftUI
import Combine
import Foundation

/// ViewModel for managing the sidebar state
class SidebarViewModel: ObservableObject {
    /// The list of all available library folders
    @Published var folders: [SidebarFolder] = SidebarFolder.allFolders
    
    /// The currently selected folder
    @Published var selectedFolder: SidebarFolder? = SidebarFolder.allFolders.first {
        didSet {
            if selectedFolder?.name == "Samples" {
                // Reset navigation history when selecting the root Samples folder
                folderNavigationHistory.removeAll()
                loadSamplesFromDisk()
            } else {
                // For other folders, just use their static items
                selectedFolderItems = selectedFolder?.items ?? []
                folderLoadError = nil
            }
        }
    }
    
    /// Flag to track if we're currently loading folder contents
    @Published var isLoadingContents: Bool = false
    
    /// Error message if folder loading fails
    @Published var folderLoadError: String? = nil
    
    /// The items in the currently selected folder
    @Published private(set) var selectedFolderItems: [FolderItem] = []
    
    /// Navigation history for folder browsing
    @Published private(set) var folderNavigationHistory: [(name: String, path: String)] = []
    
    /// Whether the current folder supports navigation (like the Samples folder)
    var supportsNavigation: Bool {
        return selectedFolder?.name == "Samples" || !folderNavigationHistory.isEmpty
    }
    
    /// The current folder path for display
    var currentFolderPath: String {
        if folderNavigationHistory.isEmpty {
            return selectedFolder?.name ?? ""
        } else {
            return folderNavigationHistory.map { $0.name }.joined(separator: " / ")
        }
    }
    
    init() {
        // Load initial folder items if Samples is the first folder
        if selectedFolder?.name == "Samples" {
            loadSamplesFromDisk()
        } else {
            selectedFolderItems = selectedFolder?.items ?? []
        }
    }
    
    /// Navigate back to the parent folder
    func navigateBack() {
        guard !folderNavigationHistory.isEmpty else { return }
        
        // Remove the current folder from history
        folderNavigationHistory.removeLast()
        
        if folderNavigationHistory.isEmpty {
            // If we're back at the root, reload the samples folder
            loadSamplesFromDisk()
        } else {
            // Load the parent folder
            let parentFolder = folderNavigationHistory.last!
            loadSamplesFromPath(parentFolder.path)
        }
    }
    
    /// Navigate to root folder
    func navigateToRoot() {
        folderNavigationHistory.removeAll()
        loadSamplesFromDisk()
    }
    
    /// Select a library folder
    func selectFolder(_ folder: SidebarFolder) {
        DispatchQueue.main.async {
            self.selectedFolder = folder
        }
    }
    
    /// Load samples from the configured samples folder
    private func loadSamplesFromDisk() {
        // Set loading state
        DispatchQueue.main.async {
            self.isLoadingContents = true
            self.folderLoadError = nil
        }
        
        // Perform disk operations on a background queue
        DispatchQueue.global(qos: .userInitiated).async {
            // Get the path before we start the operation
            let path = SettingsViewModel.shared.samplesFolderPath
            let fileManager = FileManager.default
            
            // Check if directory exists and we have access
            guard fileManager.fileExists(atPath: path) else {
                DispatchQueue.main.async {
                    self.folderLoadError = "Samples folder does not exist"
                    self.selectedFolderItems = []
                    self.isLoadingContents = false
                }
                return
            }
            
            // Try to access the directory
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: path)
                let audioExtensions = ["wav", "mp3", "aif", "aiff", "m4a", "flac"]
                
                // Filter for audio files and create FolderItems
                let audioFiles = contents.filter { file in
                    let ext = (file as NSString).pathExtension.lowercased()
                    return audioExtensions.contains(ext)
                }.map { file in
                    let filePath = (path as NSString).appendingPathComponent(file)
                    return FolderItem(
                        name: file,
                        icon: "waveform",
                        metadata: [
                            "type": "file",
                            "path": filePath
                        ]
                    )
                }
                
                // Filter for directories and create FolderItems
                let directories = contents.filter { file in
                    var isDirectory: ObjCBool = false
                    let fullPath = (path as NSString).appendingPathComponent(file)
                    return fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory) && isDirectory.boolValue
                }.map { dir in
                    let dirPath = (path as NSString).appendingPathComponent(dir)
                    return FolderItem(
                        name: dir,
                        icon: "folder",
                        metadata: [
                            "type": "folder",
                            "path": dirPath
                        ]
                    )
                }
                
                // Sort both arrays
                let sortedAudioFiles = audioFiles.sorted { item1, item2 in
                    item1.name.localizedStandardCompare(item2.name) == .orderedAscending
                }
                
                let sortedDirectories = directories.sorted { item1, item2 in
                    item1.name.localizedStandardCompare(item2.name) == .orderedAscending
                }
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    self.selectedFolderItems = sortedDirectories + sortedAudioFiles
                    self.folderLoadError = nil
                    self.isLoadingContents = false
                }
                
            } catch {
                DispatchQueue.main.async {
                    if (error as NSError).code == NSFileReadNoPermissionError {
                        self.folderLoadError = "No permission to access samples folder"
                    } else {
                        self.folderLoadError = "Error loading samples: \(error.localizedDescription)"
                    }
                    self.selectedFolderItems = []
                    self.isLoadingContents = false
                }
            }
        }
    }
    
    /// Navigate to a subfolder
    func navigateToSubfolder(_ item: FolderItem) {
        guard let path = item.metadata?["path"],
              let type = item.metadata?["type"],
              type == "folder" else {
            return
        }
        
        // Set loading state
        DispatchQueue.main.async {
            self.isLoadingContents = true
            self.folderLoadError = nil
        }
        
        // Add current folder to navigation history
        folderNavigationHistory.append((name: item.name, path: path))
        
        // Load subfolder contents on background queue
        DispatchQueue.global(qos: .userInitiated).async {
            let items = self.loadSamplesFromPath(path)
            
            // Update UI on main thread
            DispatchQueue.main.async {
                self.selectedFolderItems = items
                self.isLoadingContents = false
            }
        }
    }
    
    /// Load samples from a specific path
    private func loadSamplesFromPath(_ path: String) -> [FolderItem] {
        let fileManager = FileManager.default
        
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: path)
            let audioExtensions = ["wav", "mp3", "aif", "aiff", "m4a", "flac"]
            
            // Filter for audio files and create FolderItems
            let audioFiles = contents.filter { file in
                let ext = (file as NSString).pathExtension.lowercased()
                return audioExtensions.contains(ext)
            }.map { file in
                let filePath = (path as NSString).appendingPathComponent(file)
                return FolderItem(
                    name: file,
                    icon: "waveform",
                    metadata: [
                        "type": "file",
                        "path": filePath
                    ]
                )
            }
            
            // Filter for directories and create FolderItems
            let directories = contents.filter { file in
                var isDirectory: ObjCBool = false
                let fullPath = (path as NSString).appendingPathComponent(file)
                return fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory) && isDirectory.boolValue
            }.map { dir in
                let dirPath = (path as NSString).appendingPathComponent(dir)
                return FolderItem(
                    name: dir,
                    icon: "folder",
                    metadata: [
                        "type": "folder",
                        "path": dirPath
                    ]
                )
            }
            
            // Sort both arrays
            let sortedAudioFiles = audioFiles.sorted { item1, item2 in
                item1.name.localizedStandardCompare(item2.name) == .orderedAscending
            }
            
            let sortedDirectories = directories.sorted { item1, item2 in
                item1.name.localizedStandardCompare(item2.name) == .orderedAscending
            }
            
            // Return directories first, then audio files
            return sortedDirectories + sortedAudioFiles
            
        } catch {
            folderLoadError = "Error loading samples: \(error.localizedDescription)"
            return []
        }
    }
} 