import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        HSplitView {
            // Left sidebar with tabs
            List(SettingsViewModel.SettingsTab.allCases, id: \.self) { tab in
                ZStack {
                    // Background for selection
                    Rectangle()
                        .fill(viewModel.selectedTab == tab ? themeManager.secondaryBackgroundColor : Color.clear)
                    
                    // Content
                    HStack {
                        Text(tab.rawValue)
                            .foregroundColor(themeManager.primaryTextColor)
                            .tag(tab)
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                }
                .listRowInsets(EdgeInsets()) // Remove default list row padding
                .contentShape(Rectangle())
                .frame(maxWidth: .infinity, minHeight: 28)
                .onTapGesture {
                    viewModel.selectedTab = tab
                }
            }
            .frame(minWidth: 150, maxWidth: 200)
            .listStyle(SidebarListStyle())
            
            // Right content area
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch viewModel.selectedTab {
                    case .audio:
                        AudioSettingsView(viewModel: viewModel)
                    case .lookFeel:
                        LookAndFeelSettingsView()
                    case .shortcuts:
                        KeyboardShortcutsView()
                    default:
                        Text("\(viewModel.selectedTab.rawValue) settings coming soon")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .foregroundColor(themeManager.primaryTextColor)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(minWidth: 400, maxWidth: .infinity)
        }
        .background(themeManager.backgroundColor)
        .frame(minWidth: 600, minHeight: 400)
    }
}

// Keyboard Shortcuts View
struct KeyboardShortcutsView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    
    // Define all keyboard shortcuts
    private let shortcuts: [ShortcutCategory] = [
        ShortcutCategory(
            name: "Timeline",
            shortcuts: [
                ShortcutItem(name: "Copy Clip(s)", shortcut: "⌘C"),
                ShortcutItem(name: "Paste Clip(s)", shortcut: "⌘V"),
                ShortcutItem(name: "Zoom In", shortcut: "⌘+"),
                ShortcutItem(name: "Zoom In", shortcut: "⌘+"),
                ShortcutItem(name: "Zoom Out", shortcut: "⌘-"),
                ShortcutItem(name: "Add Audio Track", shortcut: "⌘T"),
                ShortcutItem(name: "Add MIDI Track", shortcut: "⇧⌘T"),
                ShortcutItem(name: "Create MIDI Clip", shortcut: "⇧⌘M"),
                ShortcutItem(name: "Select Track Above", shortcut: "↑"),
                ShortcutItem(name: "Select Track Below", shortcut: "↓"),
                ShortcutItem(name: "Move Playhead Left", shortcut: "←"),
                ShortcutItem(name: "Move Playhead Right", shortcut: "→"),
                ShortcutItem(name: "Move Playhead Left with Selection", shortcut: "⇧←"),
                ShortcutItem(name: "Move Playhead Right with Selection", shortcut: "⇧→"),
            ]
        ),
        ShortcutCategory(
            name: "Playback",
            shortcuts: [
                ShortcutItem(name: "Play/Pause", shortcut: "Space"),
                ShortcutItem(name: "Rewind to Start", shortcut: "⇧⌘←")
            ]
        ),
        ShortcutCategory(
            name: "Midi Editor",
            shortcuts: [
                ShortcutItem(name: "Delete Selected Clip", shortcut: "⌫"),
                ShortcutItem(name: "Copy Note(s)", shortcut: "⌘C"),
                ShortcutItem(name: "Paste Note(s)", shortcut: "⌘V")
            ]
        ),
        ShortcutCategory(
            name: "Effects Rack / Midi Editor",
            shortcuts: [
                ShortcutItem(name: "Switch Tab", shortcut: "tab"),
            ]
        )
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Title with information about future editable shortcuts
            VStack(alignment: .leading, spacing: 8) {
                Text("Keyboard Shortcuts")
                    .foregroundColor(themeManager.primaryTextColor)
                    .font(.title2)
                    .bold()
                
                Text("Editable keyboard shortcuts coming soon")
                    .font(.subheadline)
                    .foregroundColor(themeManager.primaryTextColor.opacity(0.7))
                    .italic()
            }
            .padding(.bottom, 8)
            
            // List of shortcuts by category
            ForEach(shortcuts) { category in
                VStack(alignment: .leading, spacing: 8) {
                    Text(category.name)
                        .font(.headline)
                        .foregroundColor(themeManager.primaryTextColor)
                        .padding(.bottom, 4)
                    
                    // Shortcuts table
                    VStack(spacing: 2) {
                        ForEach(category.shortcuts) { shortcut in
                            HStack {
                                Text(shortcut.name)
                                    .foregroundColor(themeManager.primaryTextColor)
                                    .frame(width: 160, alignment: .leading)
                                
                                Spacer()
                                
                                Text(shortcut.shortcut)
                                    .foregroundColor(themeManager.primaryTextColor)
                                    .font(.system(.body, design: .monospaced))
                                    .padding(4)
                                    .background(themeManager.secondaryBackgroundColor)
                                    .cornerRadius(4)
                                    .frame(width: 100, alignment: .center)
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(category.shortcuts.firstIndex(of: shortcut)! % 2 == 0 ? themeManager.backgroundColor : themeManager.tertiaryBackgroundColor.opacity(0.3))
                            .cornerRadius(2)
                        }
                    }
                    .background(themeManager.secondaryBackgroundColor.opacity(0.1))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(themeManager.secondaryBorderColor, lineWidth: 0.5)
                    )
                }
                .padding(.bottom, 12)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// Models for keyboard shortcuts
struct ShortcutCategory: Identifiable {
    let id = UUID()
    let name: String
    let shortcuts: [ShortcutItem]
}

struct ShortcutItem: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let shortcut: String
    
    static func == (lhs: ShortcutItem, rhs: ShortcutItem) -> Bool {
        return lhs.id == rhs.id
    }
}

struct LookAndFeelSettingsView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var playheadColor: Color = Color.black
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Theme Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Theme")
                    .bold()
                    .foregroundColor(themeManager.primaryTextColor)
                Picker("", selection: Binding(
                    get: { themeManager.currentTheme },
                    set: { 
                        themeManager.setTheme($0)
                        // Update displayed color when theme changes
                        playheadColor = themeManager.playheadColor
                    }
                )) {
                    ForEach(ThemeOption.allCases) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
            }
            
            // Playhead Color
            VStack(alignment: .leading, spacing: 8) {
                Text("Playhead Color")
                    .bold()
                    .foregroundColor(themeManager.primaryTextColor)
                ColorPicker("", selection: $playheadColor)
                    .onChange(of: playheadColor) { newColor in
                        themeManager.setPlayheadColor(newColor)
                    }
                    .onAppear {
                        playheadColor = themeManager.playheadColor
                    }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // Also listen for theme change identifier changes
        .onChange(of: themeManager.themeChangeIdentifier) { _ in
            playheadColor = themeManager.playheadColor
        }
    }
}

struct AudioSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Driver Type
            VStack(alignment: .leading, spacing: 8) {
                Text("Driver Type")
                    .bold()
                    .foregroundColor(themeManager.primaryTextColor)
                Picker("", selection: $viewModel.driverType) {
                    ForEach(viewModel.driverTypes, id: \.self) { driver in
                        Text(driver).tag(driver)
                    }
                }
            }
            
            // Audio Input Device
            VStack(alignment: .leading, spacing: 8) {
                Text("Audio Input Device")
                    .bold()
                    .foregroundColor(themeManager.primaryTextColor)
                Picker("", selection: $viewModel.audioInputDevice) {
                    ForEach(viewModel.audioDevices, id: \.self) { device in
                        Text(device).tag(device)
                    }
                }
            }
            
            // Audio Output Device
            VStack(alignment: .leading, spacing: 8) {
                Text("Audio Output Device")
                    .bold()
                    .foregroundColor(themeManager.primaryTextColor)
                Picker("", selection: $viewModel.audioOutputDevice) {
                    ForEach(viewModel.audioDevices, id: \.self) { device in
                        Text(device).tag(device)
                    }
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#Preview {
    SettingsView(viewModel: SettingsViewModel())
        .environmentObject(ThemeManager())
} 
