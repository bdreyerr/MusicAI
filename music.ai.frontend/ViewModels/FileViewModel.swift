//
//  FileViewModel.swift
//  music.ai.frontend
//
//  Created by Ben Dreyer on 3/26/25.
//

import Foundation
import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum FileError: Error {
    case saveFailed(String)
    case loadFailed(String)
    case fileNotFound
    case encodingFailed
    case decodingFailed
}

class FileViewModel: ObservableObject {
    // MARK: - Properties
    
    @Published var recentProjects: [URL] = []
    private let maxRecentProjects: Int = 10
    private let recentProjectsKey = "com.glitch.recentProjects"
    
    @Published var currentProjectPath: URL?
    @Published var projectName: String = "Untitled Project"
    @Published var projectModified: Bool = false
    
    // Reference to ProjectViewModel
    private weak var projectViewModel: ProjectViewModel?
    
    // MARK: - Initialization
    
    init() {
        print("🗂️ FILE VM: Initializing FileViewModel")
        loadRecentProjects()
    }
    
    func setProjectViewModel(_ viewModel: ProjectViewModel) {
        print("🗂️ FILE VM: Setting ProjectViewModel reference")
        self.projectViewModel = viewModel
    }
    
    // MARK: - Project Operations
    
    /// Create a new project with default settings
    func createNewProject() {
        print("🗂️ FILE VM: Creating new project")
        
        // Check if current project has unsaved changes
        if projectModified {
            print("🗂️ FILE VM: Current project has unsaved changes")
            // This would typically show a dialog, but we'll implement that at the UI level
        }
        
        // Reset project state - the ProjectViewModel will be reset separately
        currentProjectPath = nil
        projectName = "Untitled Project"
        projectModified = false
        
        print("🗂️ FILE VM: New project created - Name: \(projectName)")
    }
    
    /// Save the current project to its existing path
    func saveCurrentProject() -> Bool {
        print("🗂️ FILE VM: Attempting to save current project")
        
        guard let projectViewModel = projectViewModel else {
            print("❌ FILE VM: Cannot save - ProjectViewModel is nil")
            return false
        }
        
        // If we don't have a current path, we need to save as
        guard let savePath = currentProjectPath else {
            print("🗂️ FILE VM: No current path - redirecting to Save As")
            return saveProjectAs()
        }
        
        print("🗂️ FILE VM: Saving to existing path: \(savePath.path)")
        return saveProjectToFile(at: savePath)
    }
    
    /// Save the current project to a new file path
    func saveProjectAs() -> Bool {
        print("🗂️ FILE VM: Opening Save As dialog")
        
        guard let projectViewModel = projectViewModel else {
            print("❌ FILE VM: Cannot save - ProjectViewModel is nil")
            return false
        }
        
        let savePanel = NSSavePanel()
        savePanel.title = "Save Glitch Project"
        savePanel.nameFieldLabel = "Project Name:"
        savePanel.nameFieldStringValue = projectName
        savePanel.canCreateDirectories = true
        savePanel.showsTagField = false
        savePanel.allowedContentTypes = [UTType.glitchProject]
        savePanel.allowsOtherFileTypes = false
        savePanel.isExtensionHidden = false
        
        let response = savePanel.runModal()
        
        if response == .OK, let url = savePanel.url {
            print("🗂️ FILE VM: User selected save location: \(url.path)")
            let success = saveProjectToFile(at: url)
            
            if success {
                // Update current project path and name
                currentProjectPath = url
                projectName = url.deletingPathExtension().lastPathComponent
                print("🗂️ FILE VM: Project saved as \(projectName)")
                
                // Add to recent projects
                addToRecentProjects(url)
            }
            
            return success
        } else {
            print("🗂️ FILE VM: Save As cancelled by user")
            return false
        }
    }
    
    /// Load a project from a file
    func loadProjectFromFile() -> Bool {
        print("🗂️ FILE VM: Opening file dialog to load project")
        
        guard let projectViewModel = projectViewModel else {
            print("❌ FILE VM: Cannot load - ProjectViewModel is nil")
            return false
        }
        
        let openPanel = NSOpenPanel()
        openPanel.title = "Open Glitch Project"
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowsMultipleSelection = false
        openPanel.allowedContentTypes = [UTType.glitchProject]
        
        let response = openPanel.runModal()
        
        if response == .OK, let url = openPanel.url {
            print("🗂️ FILE VM: User selected file to open: \(url.path)")
            let success = loadProjectFromFile(at: url)
            
            if success {
                // Add to recent projects
                addToRecentProjects(url)
            }
            
            return success
        } else {
            print("🗂️ FILE VM: Open cancelled by user")
            return false
        }
    }
    
    /// Load a specific project file
    func loadProjectFromFile(at url: URL) -> Bool {
        print("🗂️ FILE VM: Loading project from file: \(url.path)")
        
        guard let projectViewModel = projectViewModel else {
            print("❌ FILE VM: Cannot load - ProjectViewModel is nil")
            return false
        }
        
        do {
            let data = try Data(contentsOf: url)
            print("🗂️ FILE VM: File loaded, size: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))")
            
            // Verify the file contains valid JSON
            guard let _ = try? JSONSerialization.jsonObject(with: data, options: []) else {
                print("❌ FILE VM: File does not contain valid JSON")
                throw FileError.decodingFailed
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let glitchProject = try decoder.decode(GlitchProject.self, from: data)
            print("🗂️ FILE VM: Project decoded successfully: \(glitchProject.name)")
            
            // Update the ProjectViewModel with the loaded data
            updateProjectViewModel(with: glitchProject)
            
            // Update current project info
            currentProjectPath = url
            projectName = glitchProject.name
            projectModified = false
            
            print("✅ FILE VM: Project loaded successfully")
            return true
            
        } catch let error as FileError {
            print("❌ FILE VM: File error: \(error)")
            return false
        } catch let error as DecodingError {
            print("❌ FILE VM: JSON decoding error: \(error)")
            return false
        } catch let error as NSError {
            print("❌ FILE VM: Failed to load project: \(error.localizedDescription)")
            
            if error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
                print("❌ FILE VM: File not found")
            }
            
            return false
        }
    }
    
    // MARK: - Helper Methods
    
    /// Get the current project as a GlitchProject model
    func getCurrentProject() -> GlitchProject? {
        print("🗂️ FILE VM: Getting current project data")
        
        guard let projectViewModel = projectViewModel else {
            print("❌ FILE VM: Cannot get current project - ProjectViewModel is nil")
            return nil
        }
        
        // Use the existing project ID if we have a project path, otherwise generate a new ID
        let projectId: UUID
        
        if let existingPath = currentProjectPath,
           let existingId = loadProjectIdFromFile(at: existingPath) {
            // Use the existing ID if we're saving to the same file
            projectId = existingId
            print("🗂️ FILE VM: Using existing project ID: \(projectId)")
        } else {
            // Generate a new ID for a new project
            projectId = UUID()
            print("🗂️ FILE VM: Generated new project ID: \(projectId)")
        }
        
        // Create a GlitchProject from the current ProjectViewModel
        let project = GlitchProject(
            id: projectId,
            name: projectName,
            author: UserDefaults.standard.string(forKey: "com.glitch.userName"),
            creationDate: Date(),
            lastModifiedDate: Date(),
            tempo: projectViewModel.tempo,
            timeSignatureBeats: projectViewModel.timeSignatureBeats,
            timeSignatureUnit: projectViewModel.timeSignatureUnit,
            tracks: projectViewModel.tracks,
            masterTrack: projectViewModel.masterTrack,
            formatVersion: 1
        )
        
        print("🗂️ FILE VM: Current project data prepared - \(project.tracks.count) tracks")
        return project
    }
    
    /// Load only the project ID from a file without loading the entire project
    private func loadProjectIdFromFile(at url: URL) -> UUID? {
        do {
            let data = try Data(contentsOf: url)
            
            // Try to extract just the ID using JSONSerialization for efficiency
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let idString = json["id"] as? String,
               let uuid = UUID(uuidString: idString) {
                return uuid
            }
            
            // If the above approach fails, try to decode the whole project
            let decoder = JSONDecoder()
            let project = try decoder.decode(GlitchProject.self, from: data)
            return project.id
            
        } catch {
            print("⚠️ FILE VM: Could not extract project ID: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Load recent projects from UserDefaults
    func loadRecentProjects() {
        print("🗂️ FILE VM: Loading recent projects from UserDefaults")
        
        if let recentProjectsData = UserDefaults.standard.object(forKey: recentProjectsKey) as? [Data] {
            recentProjects = recentProjectsData.compactMap { bookmarkData in
                do {
                    var isStale = false
                    let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
                    
                    if isStale {
                        print("⚠️ FILE VM: Bookmark is stale for \(url.path)")
                    }
                    
                    return url
                } catch {
                    print("❌ FILE VM: Failed to resolve bookmark: \(error.localizedDescription)")
                    return nil
                }
            }
            
            print("🗂️ FILE VM: Loaded \(recentProjects.count) recent projects")
        } else {
            print("🗂️ FILE VM: No recent projects found in UserDefaults")
        }
    }
    
    /// Add a project to the recent projects list
    private func addToRecentProjects(_ url: URL) {
        print("🗂️ FILE VM: Adding project to recent list: \(url.path)")
        
        // Remove the URL if it's already in the list
        recentProjects.removeAll { $0.path == url.path }
        
        // Add the URL to the beginning of the list
        recentProjects.insert(url, at: 0)
        
        // Limit the list to maxRecentProjects
        if recentProjects.count > maxRecentProjects {
            recentProjects = Array(recentProjects.prefix(maxRecentProjects))
        }
        
        // Save the updated list to UserDefaults
        saveRecentProjects()
        
        print("🗂️ FILE VM: Recent projects updated, count: \(recentProjects.count)")
    }
    
    /// Save recent projects to UserDefaults
    func saveRecentProjects() {
        print("🗂️ FILE VM: Saving recent projects to UserDefaults")
        
        let bookmarkData = recentProjects.compactMap { url -> Data? in
            do {
                return try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            } catch {
                print("❌ FILE VM: Failed to create bookmark for \(url.path): \(error.localizedDescription)")
                return nil
            }
        }
        
        UserDefaults.standard.set(bookmarkData, forKey: recentProjectsKey)
        print("🗂️ FILE VM: Saved \(bookmarkData.count) recent project bookmarks")
    }
    
    /// Save current project to a file at the given URL
    private func saveProjectToFile(at url: URL) -> Bool {
        print("🗂️ FILE VM: Saving project to file: \(url.path)")
        
        guard let project = getCurrentProject() else {
            print("❌ FILE VM: Failed to get current project data")
            return false
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            
            let jsonData = try encoder.encode(project)
            print("🗂️ FILE VM: Project encoded successfully as JSON, size: \(ByteCountFormatter.string(fromByteCount: Int64(jsonData.count), countStyle: .file))")
            
            try jsonData.write(to: url)
            print("✅ FILE VM: Project saved successfully to \(url.path)")
            
            // Update project state
            projectModified = false
            return true
            
        } catch {
            print("❌ FILE VM: Failed to save project: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Update the ProjectViewModel with data from a loaded GlitchProject
    private func updateProjectViewModel(with project: GlitchProject) {
        print("🗂️ FILE VM: Updating ProjectViewModel with loaded project data")
        
        guard let projectViewModel = projectViewModel else {
            print("❌ FILE VM: Cannot update - ProjectViewModel is nil")
            return
        }
        
        // Stop playback if it's running
        if projectViewModel.isPlaying {
            projectViewModel.togglePlayback()
        }
        
        // Update project settings
        projectViewModel.tempo = project.tempo
        projectViewModel.timeSignatureBeats = project.timeSignatureBeats
        projectViewModel.timeSignatureUnit = project.timeSignatureUnit
        
        // Reset playback position
        projectViewModel.seekToBeat(0)
        
        // Update tracks
        projectViewModel.tracks = project.tracks
        projectViewModel.masterTrack = project.masterTrack
        
        // Select the first track by default if available
        if !projectViewModel.tracks.isEmpty {
            projectViewModel.selectedTrackId = projectViewModel.tracks[0].id
        }
        
        print("✅ FILE VM: ProjectViewModel updated with \(project.tracks.count) tracks")
        
        // Force the view to refresh
        DispatchQueue.main.async {
            projectViewModel.objectWillChange.send()
        }
    }
    
    /// Mark the project as modified
    func markAsModified() {
        if !projectModified {
            print("🗂️ FILE VM: Marking project as modified")
            projectModified = true
        }
    }
    
    /// Check if there are unsaved changes and offer to save
    func checkUnsavedChanges(completion: @escaping (Bool) -> Void) {
        print("🗂️ FILE VM: Checking for unsaved changes")
        
        if !projectModified {
            print("🗂️ FILE VM: No unsaved changes")
            completion(true)
            return
        }
        
        print("🗂️ FILE VM: Unsaved changes detected")
        
        let alert = NSAlert()
        alert.messageText = "Do you want to save the changes made to \(projectName)?"
        alert.informativeText = "Your changes will be lost if you don't save them."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Don't Save")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn: // Save
            print("🗂️ FILE VM: User chose to save changes")
            let saved = saveCurrentProject()
            completion(saved)
            
        case .alertSecondButtonReturn: // Don't Save
            print("🗂️ FILE VM: User chose not to save changes")
            completion(true)
            
        default: // Cancel
            print("🗂️ FILE VM: User cancelled the operation")
            completion(false)
        }
    }
}
