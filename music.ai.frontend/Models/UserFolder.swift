import Foundation
import SwiftUI

/// Represents a user-added folder from disk
class UserFolder: Identifiable, ObservableObject {
    let id: UUID
    let url: URL
    let name: String
    let bookmarkData: Data?
    var bookmark: URL?
    @Published var audioFiles: [FolderItem] = []
    @Published var subfolders: [FolderItem] = []
    @Published var accessError: Error?
    @Published var currentPath: URL
    @Published var pathHistory: [URL] = []
    
    init(id: UUID = UUID(), name: String? = nil, url: URL, bookmarkData: Data? = nil) {
        self.id = id
        self.url = url
        self.currentPath = url
        self.name = name ?? url.lastPathComponent
        self.bookmarkData = bookmarkData
        
        // If we have bookmark data, try to create a security-scoped URL
        if let bookmarkData = bookmarkData {
            do {
                var isStale = false
                let resolvedURL = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
                self.bookmark = resolvedURL
            } catch {
                print("Failed to resolve bookmark during init: \(error.localizedDescription)")
                self.bookmark = nil
            }
        }
    }
    
    /// Navigate to a subfolder
    func navigateToSubfolder(_ folderPath: String) {
        // Save current path to history
        pathHistory.append(currentPath)
        
        // Update current path
        currentPath = URL(fileURLWithPath: folderPath)
        
        // Scan the new folder
        scanForAudioFiles()
    }
    
    /// Navigate back to the previous folder
    func navigateBack() -> Bool {
        guard !pathHistory.isEmpty else {
            return false
        }
        
        // Get the last path from history
        currentPath = pathHistory.removeLast()
        
        // Scan the folder
        scanForAudioFiles()
        return true
    }
    
    /// Navigate to the root folder
    func navigateToRoot() {
        if currentPath != url {
            pathHistory = []
            currentPath = url
            scanForAudioFiles()
        }
    }
    
    /// Get the relative path from the root folder
    func getRelativePath() -> String {
        if currentPath == url {
            return ""
        }
        
        let rootPath = url.path
        let currentPathString = currentPath.path
        
        if currentPathString.hasPrefix(rootPath) {
            let relativePath = String(currentPathString.dropFirst(rootPath.count))
            return relativePath.hasPrefix("/") ? String(relativePath.dropFirst()) : relativePath
        }
        
        return currentPath.lastPathComponent
    }
    
    /// Scan the folder for audio files and subfolders
    func scanForAudioFiles() {
        audioFiles = []
        subfolders = []
        accessError = nil
        
        let fileManager = FileManager.default
        
        // Check if the folder exists and is accessible
        guard fileManager.fileExists(atPath: currentPath.path) else {
            let error = NSError(domain: "UserFolderError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Folder does not exist: \(currentPath.path)"])
            accessError = error
            print("Folder does not exist: \(currentPath.path)")
            return
        }
        
        // Try to access the folder
        do {
            // Get all items in the directory (non-recursive)
            let fileURLs = try fileManager.contentsOfDirectory(
                at: currentPath,
                includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .contentTypeKey],
                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
            )
            
            // Process each item
            for fileURL in fileURLs {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey])
                
                if resourceValues.isDirectory == true {
                    // It's a subfolder
                    let folderName = fileURL.lastPathComponent
                    
                    subfolders.append(FolderItem(
                        name: folderName,
                        icon: "folder",
                        metadata: [
                            "path": fileURL.path,
                            "type": "folder"
                        ]
                    ))
                } else if resourceValues.isRegularFile == true {
                    // It's a file - check if it's an audio file
                    let fileExtension = fileURL.pathExtension.lowercased()
                    if ["mp3", "wav", "aiff", "m4a", "flac", "aac", "ogg"].contains(fileExtension) {
                        let fileName = fileURL.deletingPathExtension().lastPathComponent
                        
                        // Choose icon based on file type
                        let icon: String
                        switch fileExtension {
                        case "mp3", "m4a", "aac", "ogg", "flac":
                            icon = "music.note"
                        case "wav", "aiff":
                            icon = "waveform"
                        default:
                            icon = "doc.text"
                        }
                        
                        audioFiles.append(FolderItem(
                            name: fileName,
                            icon: icon,
                            metadata: [
                                "path": fileURL.path,
                                "extension": fileExtension,
                                "type": "file"
                            ]
                        ))
                    }
                }
            }
            
            // Sort alphabetically
            subfolders.sort { $0.name.lowercased() < $1.name.lowercased() }
            audioFiles.sort { $0.name.lowercased() < $1.name.lowercased() }
            
        } catch {
            accessError = error
            print("Error scanning directory: \(error.localizedDescription)")
        }
    }
} 