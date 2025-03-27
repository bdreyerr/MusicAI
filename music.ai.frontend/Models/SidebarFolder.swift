import SwiftUI

/// Represents a folder in the sidebar
struct SidebarFolder: Identifiable {
    var id = UUID()
    var name: String
    var icon: String // SF Symbol name
    var items: [FolderItem]
    
    /// Predefined folders for the sidebar
    static let allFolders: [SidebarFolder] = [
        SidebarFolder(
            name: "Instruments",
            icon: "guitars",
            items: [
                FolderItem(name: "Piano", icon: "pianokeys"),
                FolderItem(name: "Guitar", icon: "guitars"),
                FolderItem(name: "Drums", icon: "music.quarternote.3"),
                FolderItem(name: "Synth", icon: "waveform")
            ]
        ),
        SidebarFolder(
            name: "Plugins",
            icon: "powerplug",
            items: [
                FolderItem(name: "Compressor", icon: "dial.min"),
                FolderItem(name: "Equalizer", icon: "slider.horizontal.3"),
                FolderItem(name: "Reverb", icon: "waveform.path.ecg"),
                FolderItem(name: "Delay", icon: "clock")
            ]
        ),
        SidebarFolder(
            name: "Samples",
            icon: "folder",
            items: [
                FolderItem(name: "Drum Loops", icon: "music.note.list"),
                FolderItem(name: "Bass Loops", icon: "music.note"),
                FolderItem(name: "Vocal Samples", icon: "mic"),
                FolderItem(name: "Sound FX", icon: "speaker.wave.3")
            ]
        ),
        SidebarFolder(
            name: "Audio Effects",
            icon: "waveform",
            items: [
                FolderItem(name: "Distortion", icon: "waveform.path"),
                FolderItem(name: "Chorus", icon: "waveform.badge.plus"),
                FolderItem(name: "Flanger", icon: "waveform.path.badge.minus"),
                FolderItem(name: "Phaser", icon: "waveform.path.ecg.rectangle")
            ]
        ),
        SidebarFolder(
            name: "MIDI Effects",
            icon: "pianokeys",
            items: [
                FolderItem(name: "Arpeggiator", icon: "arrow.up.and.down"),
                FolderItem(name: "Chord Trigger", icon: "square.grid.3x3"),
                FolderItem(name: "Scale", icon: "music.note"),
                FolderItem(name: "Transpose", icon: "arrow.left.and.right")
            ]
        )
    ]
}

/// Represents an item within a folder
struct FolderItem: Identifiable {
    var id = UUID()
    var name: String
    var icon: String // SF Symbol name
    var metadata: [String: String]? // Optional metadata for storing file paths, etc.
    
    init(name: String, icon: String, metadata: [String: String]? = nil) {
        self.name = name
        self.icon = icon
        self.metadata = metadata
    }
} 
