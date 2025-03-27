import Foundation
import SwiftUI

class SettingsViewModel: ObservableObject {
    /// Shared instance
    static let shared = SettingsViewModel()
    
    @Published var selectedTab: SettingsTab = .profileAccount
    @Published var driverType: String = "CoreAudio"
    @Published var audioInputDevice: String = "No Device"
    @Published var audioOutputDevice: String = "No Device"
    @Published var samplesFolderPath: String
    
    // Keys for UserDefaults
    private let samplesFolderPathKey = "samplesFolderPath"
    private let samplesFolderBookmarkKey = "samplesFolderBookmark"
    
    // Audio device options (these would normally be populated from the system)
    let driverTypes = ["CoreAudio"]
    let audioDevices = ["No Device", "Built-in Output", "Built-in Input"]
    
    private init() {
        // Set default samples folder path to ~/Documents/Samples
        let homeDirectory = NSHomeDirectory()
        let defaultSamplesPath = (homeDirectory as NSString).appendingPathComponent("Documents/Samples")
        
        // Load saved path from UserDefaults or use default
        self.samplesFolderPath = UserDefaults.standard.string(forKey: samplesFolderPathKey) ?? defaultSamplesPath
        
        // Try to restore security-scoped access
        restoreSecurityScopedAccess()
    }
    
    func saveSamplesFolderPath(_ path: String) {
        samplesFolderPath = path
        UserDefaults.standard.set(path, forKey: samplesFolderPathKey)
        
        // Create and save security-scoped bookmark
        let url = URL(fileURLWithPath: path)
        do {
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmarkData, forKey: samplesFolderBookmarkKey)
            print("✅ Saved security-scoped bookmark for samples folder")
        } catch {
            print("⚠️ Failed to create security-scoped bookmark: \(error)")
        }
    }
    
    private func restoreSecurityScopedAccess() {
        guard let bookmarkData = UserDefaults.standard.data(forKey: samplesFolderBookmarkKey) else {
            print("ℹ️ No saved security-scoped bookmark found")
            return
        }
        
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            if isStale {
                print("⚠️ Bookmark is stale, need to create a new one")
                // We'll create a new bookmark next time the user selects the folder
                return
            }
            
            let success = url.startAccessingSecurityScopedResource()
            if success {
                print("✅ Successfully restored security-scoped access to samples folder")
                // We intentionally don't stop accessing the resource since we need ongoing access
            } else {
                print("⚠️ Failed to start accessing security-scoped resource")
            }
        } catch {
            print("⚠️ Failed to resolve security-scoped bookmark: \(error)")
        }
    }
    
    /// Opens the settings window and navigates to the specified tab
    func openSettings(selectTab tab: SettingsTab) {
        // First open the settings window
        DispatchQueue.main.async {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            // Then set the selected tab
            self.selectedTab = tab
        }
    }
    
    enum SettingsTab: String, CaseIterable {
        case profileAccount = "Profile & Account"
        case lookFeel = "Look & Feel"
        case audio = "Audio"
        case shortcuts = "Keyboard Shortcuts"
        case fileFolder = "File & Folder"
        case plugins = "Plugins"
        case recordWarp = "Record & Warp"
    }
} 
