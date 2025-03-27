//
//  FileTypeExtensions.swift
//  music.ai.frontend
//
//  Created by Ben Dreyer on 3/26/25.
//

import Foundation
import UniformTypeIdentifiers

extension UTType {
    /// A uniform type for Glitch Project files
    static var glitchProject: UTType {
        UTType(exportedAs: "com.glitch.project")
    }
}

// Extension to add support for UTType with older macOS versions
extension UTType {
    // Convenience initializer for creating a UTType from a file extension
    init?(filenameExtension: String, conformingTo parentType: UTType) {
        // Try to use the built-in method first
        if let type = UTType(filenameExtension: filenameExtension, conformingTo: parentType) {
            self = type
            return
        }
        
        // Fallback for older systems or if the type isn't registered yet
        if #available(macOS 11.0, *) {
            // Use the standard method on macOS 11+
            if let type = UTType(filenameExtension: filenameExtension, conformingTo: parentType) {
                self = type
                return
            }
            
            // For custom types not yet registered with the system - specify it conforms to JSON
            self.init(exportedAs: "com.glitch.project", conformingTo: .json)
        } else {
            // Fallback for macOS 10.15 and earlier - specify it conforms to JSON
            self.init(exportedAs: "com.glitch.project", conformingTo: .json)
        }
    }
} 
