import Foundation
import SwiftUI

class SettingsViewModel: ObservableObject {
    @Published var selectedTab: SettingsTab = .audio
    @Published var driverType: String = "CoreAudio"
    @Published var audioInputDevice: String = "No Device"
    @Published var audioOutputDevice: String = "No Device"
    
    // Audio device options (these would normally be populated from the system)
    let driverTypes = ["CoreAudio"]
    let audioDevices = ["No Device", "Built-in Output", "Built-in Input"]
    
    enum SettingsTab: String, CaseIterable {
        case profileAccount = "Profile & Account"
        case lookFeel = "Look & Feel"
        case audio = "Audio"
        case fileFolder = "File & Folder"
        case plugins = "Plugins"
        case recordWarp = "Record & Warp"
    }
} 