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
                    default:
                        Text("\(viewModel.selectedTab.rawValue) settings coming soon")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
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

struct LookAndFeelSettingsView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var playheadColor: Color = Color.black
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Theme Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Theme")
                    .bold()
                Picker("", selection: Binding(
                    get: { themeManager.currentTheme },
                    set: { themeManager.setTheme($0) }
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