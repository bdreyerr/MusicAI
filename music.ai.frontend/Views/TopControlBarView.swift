import SwiftUI

struct TopControlBarView: View {
    @ObservedObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isEditingTempo: Bool = false
    @State private var tempTempoValue: String = ""
    @State private var isEditingTimeSignature: Bool = false
    @State private var isMetronomeEnabled: Bool = false
    @State private var isLoopEnabled: Bool = false
    @State private var cpuUsage: Double = 12.5 // Mock CPU usage value
    
    // Custom background color for the control bar
    private var controlBarBackgroundColor: Color {
        switch themeManager.currentTheme {
        case .light:
            // Darker background in light mode to distinguish from ruler
            return Color(white: 0.78)
        case .dark:
            // Slightly lighter than the main background in dark mode
            return Color(white: 0.25)
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Left section - Tempo control with tap button
            HStack(spacing: 8) {
                // Tap tempo button
                Button(action: {
                    // Just UI feedback, no actual tempo calculation
                }) {
                    Text("Tap")
                        .font(.subheadline)
                        .foregroundColor(themeManager.primaryTextColor)
                }
                .buttonStyle(BorderlessButtonStyle())
                .frame(width: 40, height: 24)
                .background(themeManager.tertiaryBackgroundColor.opacity(0.3))
                .cornerRadius(4)
                
                Text("Tempo:")
                    .font(.subheadline)
                    .foregroundColor(themeManager.primaryTextColor)
                
                // Tempo editor with background tap detection
                ZStack(alignment: .center) {
                    if isEditingTempo {
                        TextField("", text: $tempTempoValue, onCommit: {
                            commitTempoEdit()
                        })
                        .frame(width: 50, height: 24)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .foregroundColor(themeManager.primaryTextColor)
                        .onAppear {
                            // Set focus on the text field when it appears
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                NSApp.keyWindow?.makeFirstResponder(nil)
                            }
                        }
                    } else {
                        Text("\(Int(projectViewModel.tempo))")
                            .font(.subheadline)
                            .foregroundColor(themeManager.primaryTextColor)
                            .frame(width: 50, height: 24, alignment: .center)
                            .background(themeManager.tertiaryBackgroundColor.opacity(0.3))
                            .cornerRadius(4)
                            .onTapGesture(count: 2) {
                                startTempoEdit()
                            }
                    }
                }
                .frame(width: 50, height: 24) // Fixed size for both states
                
                Text("BPM")
                    .font(.subheadline)
                    .foregroundColor(themeManager.primaryTextColor)
                
                // Metronome toggle
                Button(action: {
                    isMetronomeEnabled.toggle()
                }) {
                    Image(systemName: isMetronomeEnabled ? "circle.fill" : "circle")
                        .font(.subheadline)
                        .foregroundColor(isMetronomeEnabled ? .blue : themeManager.primaryTextColor)
                }
                .padding(.leading, 4)
                .help("Metronome")
            }
            .padding(.horizontal, 16)
            
            Divider()
                .frame(height: 24)
                .background(themeManager.secondaryBorderColor)
            
            // Time signature
            HStack(spacing: 8) {
                Text("Time:")
                    .font(.subheadline)
                    .foregroundColor(themeManager.primaryTextColor)
                
                // Time signature display/edit
                ZStack(alignment: .center) {
                    if isEditingTimeSignature {
                        // Editable time signature with pickers
                        HStack(spacing: 2) {
                            Picker("", selection: $projectViewModel.timeSignatureBeats) {
                                ForEach(2...12, id: \.self) { beats in
                                    Text("\(beats)").tag(beats)
                                        .foregroundColor(themeManager.primaryTextColor)
                                }
                            }
                            .frame(width: 45)
                            .labelsHidden()
                            
                            Text("/")
                                .foregroundColor(themeManager.primaryTextColor)
                            
                            Picker("", selection: $projectViewModel.timeSignatureUnit) {
                                ForEach([2, 4, 8, 16], id: \.self) { unit in
                                    Text("\(unit)").tag(unit)
                                        .foregroundColor(themeManager.primaryTextColor)
                                }
                            }
                            .frame(width: 45)
                            .labelsHidden()
                        }
                        .frame(width: 100, height: 24)
                    } else {
                        // Display time signature as plain text without background
                        Text("\(projectViewModel.timeSignatureBeats)/\(projectViewModel.timeSignatureUnit)")
                            .font(.subheadline)
                            .foregroundColor(themeManager.primaryTextColor)
                            .frame(height: 24, alignment: .center)
                            .onTapGesture(count: 2) {
                                startTimeSignatureEdit()
                            }
                    }
                }
                .frame(height: 24) // Fixed height, flexible width
            }
            .padding(.horizontal, 16)
            
            Spacer()
            
            // Center section - Transport controls
            HStack(spacing: 16) {
                // Rewind button (just the icon)
                Image(systemName: "backward.fill")
                    .font(.title2)
                    .foregroundColor(themeManager.primaryTextColor)
                    .onTapGesture {
                        projectViewModel.rewind()
                    }
                
                // Play/Pause button (just the icon)
                Image(systemName: projectViewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title)
                    .foregroundColor(themeManager.primaryTextColor)
                    .onTapGesture {
                        projectViewModel.togglePlayback()
                    }
                
                // Record button (just the icon)
                Image(systemName: "record.circle")
                    .font(.title2)
                    .foregroundColor(.red)
                    .onTapGesture {
                        // Record action (UI only)
                    }
                
                // Loop button
                Image(systemName: "repeat")
                    .font(.subheadline)
                    .foregroundColor(isLoopEnabled ? .blue : themeManager.primaryTextColor)
                    .onTapGesture {
                        isLoopEnabled.toggle()
                    }
                    .help("Loop playback")
            }
            
            Spacer()
            
            // Right section - Playhead position and CPU usage
            HStack(spacing: 16) {
                // Playhead position
                HStack(spacing: 8) {
                    Text("Position:")
                        .font(.subheadline)
                        .foregroundColor(themeManager.primaryTextColor)
                    
                    Text(projectViewModel.formattedPosition())
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(themeManager.primaryTextColor)
                        .frame(width: 70, alignment: .leading)
                }
                
                // CPU usage indicator
                HStack(spacing: 4) {
                    Text("CPU:")
                        .font(.subheadline)
                        .foregroundColor(themeManager.primaryTextColor)
                    
                    Text(String(format: "%.1f%%", cpuUsage))
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(cpuUsage > 80 ? .red : themeManager.primaryTextColor)
                        .frame(width: 50, alignment: .leading)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
        .frame(height: 40)
        .background(controlBarBackgroundColor)
        // .border(themeManager.borderColor, width: 1)
        // Add a global tap gesture to the entire view
        .onTapGesture {
            // This tap gesture will be triggered for taps on the control bar itself
            // We don't want to do anything here, as we handle specific taps with other gestures
        }
        // Use the environment click observer to detect clicks anywhere in the app
        .environmentObject(ClickObserver.shared)
        .onReceive(NotificationCenter.default.publisher(for: ClickObserver.clickNotification)) { _ in
            // This will be called for any click in the app
            if isEditingTempo {
                commitTempoEdit()
            }
            if isEditingTimeSignature {
                isEditingTimeSignature = false
            }
        }
        // Timer to simulate CPU usage changes
        .onAppear {
            // Start a timer to update CPU usage for demonstration
            Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                // Simulate CPU usage fluctuation between 5% and 25%
                cpuUsage = Double.random(in: 5...25)
            }
        }
    }
    
    // Helper functions for tempo editing
    private func startTempoEdit() {
        tempTempoValue = "\(Int(projectViewModel.tempo))"
        isEditingTempo = true
        // Ensure only one editor is open at a time
        isEditingTimeSignature = false
    }
    
    private func commitTempoEdit() {
        if let newTempo = Double(tempTempoValue) {
            projectViewModel.tempo = newTempo
        }
        isEditingTempo = false
    }
    
    private func cancelTempoEdit() {
        // Discard changes and exit edit mode
        isEditingTempo = false
    }
    
    // Helper function for time signature editing
    private func startTimeSignatureEdit() {
        isEditingTimeSignature = true
        // Ensure only one editor is open at a time
        isEditingTempo = false
    }
}

// Global click observer to detect clicks anywhere in the app
class ClickObserver: ObservableObject {
    static let shared = ClickObserver()
    static let clickNotification = Notification.Name("AppClickNotification")
    
    init() {
        // Set up a global event monitor for mouse down events
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { _ in
            NotificationCenter.default.post(name: Self.clickNotification, object: nil)
        }
        
        // Also monitor local events (within the app)
        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { event in
            NotificationCenter.default.post(name: Self.clickNotification, object: nil)
            return event
        }
    }
}

#Preview {
    TopControlBarView(projectViewModel: ProjectViewModel())
        .environmentObject(ThemeManager())
} 
