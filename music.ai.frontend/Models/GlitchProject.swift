//
//  GlitchProject.swift
//  music.ai.frontend
//
//  Created by Ben Dreyer on 3/26/25.
//

import Foundation
import SwiftUI

/// The main project model that gets encoded to a JSON file
struct GlitchProject: Codable {
    /// Unique identifier for this project
    var id: UUID
    
    /// Project name shown in the UI
    var name: String
    
    /// Optional author name
    var author: String?
    
    /// Date when the project was first created
    var creationDate: Date
    
    /// Date when the project was last modified
    var lastModifiedDate: Date
    
    /// Project tempo in beats per minute (BPM)
    var tempo: Double
    
    /// Number of beats per bar (time signature numerator)
    var timeSignatureBeats: Int
    
    /// Time signature denominator (4 = quarter note, 8 = eighth note, etc.)
    var timeSignatureUnit: Int
    
    /// All tracks in the project (excluding master track)
    var tracks: [Track]
    
    /// The master output track
    var masterTrack: Track
    
    /// File format version for future compatibility
    var formatVersion: Int = 1
}
