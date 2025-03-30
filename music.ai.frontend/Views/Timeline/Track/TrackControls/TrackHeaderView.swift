import SwiftUI

// MARK: - Track Header View

struct TrackHeaderView: View {
    let track: Track
    @ObservedObject var trackViewModel: TrackViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 6) {
            // Track icon with color
            Image(systemName: track.type.icon)
                .foregroundColor(trackViewModel.effectiveColor)
                .onTapGesture {
                    trackViewModel.showingColorPicker.toggle()
                }
                .popover(isPresented: $trackViewModel.showingColorPicker) {
                    ColorPickerView(trackViewModel: trackViewModel)
                }
                .help("Change track color")
            
            // Track name (editable)
            TrackNameView(trackViewModel: trackViewModel)
                .environmentObject(themeManager)
            
            Spacer()
            
            // Enable/Disable toggle (moved from controls row)
            Button(action: {
                trackViewModel.toggleEnabled()
            }) {
                Image(systemName: trackViewModel.isEnabled ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(trackViewModel.isEnabled ? .green : themeManager.primaryTextColor)
                    .font(.system(size: 12))
            }
            .buttonStyle(BorderlessButtonStyle())
            .help(trackViewModel.isEnabled ? "Disable Track" : "Enable Track")
            
            // Solo button (moved from controls row)
            Button(action: {
                trackViewModel.toggleSolo()
            }) {
                Image(systemName: trackViewModel.isSolo ? "s.square.fill" : "s.square")
                    .font(.system(size: 12))
                    .foregroundColor(trackViewModel.isSolo ? .yellow : themeManager.primaryTextColor)
            }
            .buttonStyle(BorderlessButtonStyle())
            .help(trackViewModel.isSolo ? "Unsolo Track (Exclusive)" : "Solo Track (Exclusive)")
            
            // Collapse/expand indicator
            Button(action: {
                trackViewModel.toggleCollapsed()
            }) {
                Image(systemName: trackViewModel.isCollapsed ? "chevron.down" : "chevron.up")
                    .font(.system(size: 13))
                    .foregroundColor(themeManager.primaryTextColor.opacity(0.7))
                    .padding(.trailing, 8)
                }
            .buttonStyle(BorderlessButtonStyle())
            .help(trackViewModel.isCollapsed ? "Expand track" : "Collapse track")
        }
        .padding(.leading, 8)
        .padding(.top, 4)
    }
}

// MARK: - Color Picker View

struct ColorPickerView: View {
    @ObservedObject var trackViewModel: TrackViewModel
    
    var body: some View {
        VStack(spacing: 10) {
            Text("Track Color")
                .font(.headline)
                .padding(.top, 8)
            
            ColorPicker("Select Color", selection: Binding(
                get: { trackViewModel.effectiveColor },
                set: { newColor in
                    trackViewModel.customColor = newColor
                    trackViewModel.updateTrackColor(newColor)
                }
            ))
            .padding(.horizontal)
            
            Button("Reset to Default") {
                trackViewModel.customColor = nil
                trackViewModel.updateTrackColor(nil)
                trackViewModel.showingColorPicker = false
            }
            .padding(.bottom, 8)
        }
        .frame(width: 250)
        .padding(8)
    }
}

// MARK: - Track Name View

struct TrackNameView: View {
    @ObservedObject var trackViewModel: TrackViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        if trackViewModel.isEditingName {
            TextField("Track name", text: $trackViewModel.trackName, onCommit: {
                trackViewModel.isEditingName = false
                trackViewModel.updateTrackName()
            })
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .frame(width: 120)
            .onExitCommand {
                trackViewModel.isEditingName = false
                trackViewModel.updateTrackName()
            }
        } else {
            Text(trackViewModel.trackName)
                .font(.subheadline)
                .foregroundColor(themeManager.primaryTextColor)
                .lineLimit(1)
                .onTapGesture(count: 2) {
                    trackViewModel.isEditingName = true
                }
                .help("Double-click to rename")
        }
    }
} 