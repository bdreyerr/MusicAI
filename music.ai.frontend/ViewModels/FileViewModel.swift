//
//  FileViewModel.swift
//  music.ai.frontend
//
//  Created by Ben Dreyer on 3/26/25.
//

import Foundation

struct GlitchProject: Codable {
    var id: UUID
    var name: String
    var author: String?
    var creationDate: Date
    var lastModifiedDate: Date
    var tempo: Double
    var timeSignatureBeats: Int
    var timeSignatureUnit: Int
    var tracks: [Track]
    var masterTrack: Track
}


class FileViewModel {
    @Published var recentProjects: [URL] = []
    private let maxRecentProjects: Int = 10
    
    @Published var currentProjectPath: URL?
    @Published var projectName: String = "Untilted Project"
    @Published var projectModified: Bool = false
    
    init () {
        loadRecentProjects()
    }
    
    func createNewProject() {
        
    }
    
    func saveCurrentProject() {
        
    }
    
    func loadProjectFromFile() {
        
    }
    
    func getCurrentProject() {
        
    }
    
    func loadRecentProjects() {
        
    }
    
    
}
