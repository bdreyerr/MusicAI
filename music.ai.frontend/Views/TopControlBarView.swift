import SwiftUI
import AppKit

// New component for the waveform visualization
struct SimpleWaveformView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var projectViewModel: ProjectViewModel
    
    // Store the bar heights for animation (increased count)
    @State private var barHeights: [CGFloat] = Array(repeating: 0.5, count: 14)
    @State private var updateTimer: Timer? = nil
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barHeights.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.white.opacity(0.9)) // Slightly transparent white for softer look
                    .frame(width: 3, height: barHeights[index] * 16) // Slightly smaller height
            }
        }
        .frame(width: 72, height: 20) // Wider to fit more bars
        .onAppear {
            startWaveformAnimation()
        }
        .onDisappear {
            updateTimer?.invalidate()
            updateTimer = nil
        }
        .onChange(of: projectViewModel.isPlaying) { _, isPlaying in
            if isPlaying {
                startWaveformAnimation()
            } else {
                // When stopped, set all bars to a minimal height
                withAnimation(.easeOut(duration: 0.3)) {
                    for i in 0..<barHeights.count {
                        barHeights[i] = 0.2
                    }
                }
            }
        }
    }
    
    private func startWaveformAnimation() {
        // Cancel any existing timer
        updateTimer?.invalidate()
        
        // Create a new timer that updates the waveform
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if projectViewModel.isPlaying {
                // Only animate when playing
                withAnimation(.easeInOut(duration: 0.1)) {
                    for i in 0..<barHeights.count {
                        // Generate random heights with a more realistic audio pattern
                        // Center bars tend to be taller (mid frequencies prominent in most music)
                        let centerIndex = barHeights.count / 2
                        let distanceFromCenter = abs(i - centerIndex)
                        
                        if distanceFromCenter <= 2 {
                            // Center bars (mids) - taller on average
                            barHeights[i] = CGFloat.random(in: 0.5...1.0)
                        } else if distanceFromCenter >= 5 {
                            // Outer bars (extreme lows and highs) - shorter on average
                            barHeights[i] = CGFloat.random(in: 0.1...0.6)
                        } else {
                            // Transition bars - medium height
                            barHeights[i] = CGFloat.random(in: 0.3...0.8)
                        }
                        
                        // Add some correlation between adjacent bars for a more natural look
                        if i > 0 {
                            // Slightly influence each bar by its neighbor (30% influence)
                            barHeights[i] = barHeights[i] * 0.7 + barHeights[i-1] * 0.3
                        }
                    }
                }
            }
        }
    }
}

// New component that mimics the iPhone 16 notch design
struct NotchDisplayView: View {
    @ObservedObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 16) {
            // Left side - App logo (larger)
            Image("logo")
                .resizable()
                .interpolation(.high) // Use high quality interpolation
                .antialiased(true) // Enable antialiasing
                .renderingMode(.original) // Preserve original colors
                .scaledToFit()
                .frame(width: 30, height: 30)
//                .colorInvert() // Ensure logo is visible on black background
            
            // Position displays (side by side with divider)
            HStack(spacing: 10) {
                // Bar.Beat format with larger font
                NotchPositionDisplayWrapper(projectViewModel: projectViewModel)
                
                // Small divider between position and time
                Rectangle()
                    .fill(Color.white.opacity(0.4))
                    .frame(width: 1, height: 14)
                
                // Time format (minutes:seconds)
                NotchTimeDisplayWrapper(projectViewModel: projectViewModel)
            }
            .frame(width: 120, alignment: .center) // Fix width to ensure consistent sizing
            
            // Right side - Waveform visualization
            SimpleWaveformView(projectViewModel: projectViewModel)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 5) // Further reduced height
        .background(
            Capsule()
                .fill(Color.black) // Always black in both themes
        )
        .frame(width: 280, height: 32) // Wider and shorter
        // Add a subtle shadow for depth
        .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 1)
    }
}

// Custom wrapper for position display in the notch
struct NotchPositionDisplayWrapper: View {
    @ObservedObject var projectViewModel: ProjectViewModel
    
    var body: some View {
        Text(projectViewModel.formattedPosition())
            .font(.system(.callout, design: .monospaced).weight(.bold))
            .foregroundColor(.white)
    }
}

// Custom wrapper for time display in the notch
struct NotchTimeDisplayWrapper: View {
    @ObservedObject var projectViewModel: ProjectViewModel
    @State private var displayedTimePosition: String = "0:00"
    @State private var updateTimer: Timer? = nil
    
    var body: some View {
        Text(displayedTimePosition)
            .font(.system(.callout, design: .monospaced).weight(.medium))
            .foregroundColor(.white.opacity(0.9))
            .onAppear {
                // Initialize with current position
                displayedTimePosition = formatTimePosition(projectViewModel.currentBeat, tempo: projectViewModel.tempo)
                
                // Start a timer that updates the display
                startUpdateTimer()
            }
            .onDisappear {
                // Clean up timer when view disappears
                updateTimer?.invalidate()
                updateTimer = nil
            }
            .onChange(of: projectViewModel.isPlaying) { _, isPlaying in
                if isPlaying {
                    // When playback starts, use a slower update rate
                    startUpdateTimer()
                } else {
                    // When playback stops, update immediately
                    displayedTimePosition = formatTimePosition(projectViewModel.currentBeat, tempo: projectViewModel.tempo)
                    startUpdateTimer(frequency: 10) // 10 Hz when not playing
                }
            }
    }
    
    private func startUpdateTimer(frequency: Double = 5) {
        // Cancel any existing timer
        updateTimer?.invalidate()
        
        // Create a new timer that updates at the specified frequency
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0/frequency, repeats: true) { _ in
            // Update the displayed position
            displayedTimePosition = formatTimePosition(projectViewModel.currentBeat, tempo: projectViewModel.tempo)
        }
    }
    
    // Convert beats to minutes:seconds.milliseconds format
    private func formatTimePosition(_ beats: Double, tempo: Double) -> String {
        // Convert beats to seconds based on tempo
        let secondsPerBeat = 60.0 / tempo
        let totalSeconds = beats * secondsPerBeat
        
        let minutes = Int(totalSeconds) / 60
        let seconds = Int(totalSeconds) % 60
        
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct TopControlBarView: View {
    @ObservedObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isEditingTempo: Bool = false
    @State private var tempTempoValue: String = ""
    @State private var isEditingTimeSignatureBeats: Bool = false
    @State private var isEditingTimeSignatureUnit: Bool = false
    @State private var isMetronomeEnabled: Bool = false
    @State private var isLoopEnabled: Bool = false
    @State private var cpuUsage: Double = 12.5 // Mock CPU usage value
    @State private var memoryUsage: Double = 256.0 // Mock RAM usage in MB
    
    // Using a separate controller for text field operations to avoid view cycle issues
    private let tempoFieldController = TempoFieldController()
    
    // Constants for BPM limits
    private let minBPM: Double = 1.0
    private let maxBPM: Double = 800.0
    
    var body: some View {
        HStack(spacing: 0) {
            // Notch display (moved to left side)
            NotchDisplayView(projectViewModel: projectViewModel)
                .padding(.vertical, 1)
                .padding(.leading, 14)
                .padding(.trailing, 20)
            
            // Left group with controls
            HStack(spacing: 0) {
                // BPM control with tap button
                HStack(spacing: 8) {
                    // Tap tempo button
                    Button(action: {
                        // TODO: Implement tap tempo
                    }) {
                        Text("Tap")
                            .font(.subheadline)
                            .foregroundColor(themeManager.primaryTextColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(themeManager.tertiaryBackgroundColor.opacity(0.3))
                            )
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .help("Tap to set BPM")
                    
                    // Tempo editor with direct NSTextField implementation
                    ZStack(alignment: .center) {
                        if isEditingTempo {
                            // Using our custom NSTextField wrapper
                            TempoFieldWrapper(
                                initialValue: tempTempoValue,
                                themeManager: themeManager,
                                controller: tempoFieldController,
                                minValue: Int(minBPM),
                                maxValue: Int(maxBPM),
                                onCommit: { newValue in
                                    if let newTempo = Double(newValue), newTempo >= minBPM && newTempo <= maxBPM {
                                        projectViewModel.tempo = newTempo
                                    }
                                    isEditingTempo = false
                                }
                            )
                            .frame(width: 62, height: 30)
                        } else {
                            Text("\(Int(projectViewModel.tempo))")
                                .font(.system(.title3, design: .monospaced))
                                .foregroundColor(themeManager.primaryTextColor)
                                .frame(width: 50, height: 24, alignment: .center)
                                .padding(.horizontal, 6)
                                .background(themeManager.tertiaryBackgroundColor.opacity(0.3))
                                .cornerRadius(4)
                                .onTapGesture {
                                    tempTempoValue = "\(Int(projectViewModel.tempo))"
                                    isEditingTempo = true
                                    isEditingTimeSignatureBeats = false
                                    isEditingTimeSignatureUnit = false
                                }
                        }
                    }
                    .frame(width: 62, height: 30) // Fixed size for both states
                    
                    Text("BPM")
                        .font(.subheadline)
                        .foregroundColor(themeManager.primaryTextColor)
                    
                    // Metronome toggle
                    Button(action: {
                        isMetronomeEnabled.toggle()
                    }) {
                        Image(systemName: isMetronomeEnabled ? "metronome.fill" : "metronome")
                            .font(.subheadline)
                            .foregroundColor(isMetronomeEnabled ? .blue : themeManager.primaryTextColor)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .padding(.leading, 4)
                    .help("Metronome")
                }
                .padding(.horizontal, 10)
                
                Divider()
                    .frame(height: 24)
                    .background(themeManager.secondaryBorderColor)
                
                // Time signature controls
                HStack(spacing: 8) {
                    Text("Time:")
                        .font(.subheadline)
                        .foregroundColor(themeManager.primaryTextColor)
                    
                    // Beats (numerator) button
                    Button(action: {
                        isEditingTimeSignatureBeats = true
                        isEditingTimeSignatureUnit = false
                    }) {
                        Text("\(projectViewModel.timeSignatureBeats)")
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundColor(themeManager.primaryTextColor)
                            .frame(width: 30, height: 24)
                            .background(themeManager.tertiaryBackgroundColor.opacity(0.3))
                            .cornerRadius(4)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .popover(isPresented: $isEditingTimeSignatureBeats, arrowEdge: .bottom) {
                        VStack(spacing: 0) {
                            ForEach(2...12, id: \.self) { beats in
                                Button(action: {
                                    projectViewModel.timeSignatureBeats = beats
                                    isEditingTimeSignatureBeats = false
                                }) {
                                    Text("\(beats)")
                                        .frame(width: 100, height: 30)
                                        .foregroundColor(themeManager.primaryTextColor)
                                        .background(projectViewModel.timeSignatureBeats == beats ? 
                                                  themeManager.accentColor.opacity(0.2) : 
                                                  Color.clear)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.vertical, 5)
                        .background(themeManager.secondaryBackgroundColor)
                    }
                    
                    Text("/")
                        .font(.title3)
                        .foregroundColor(themeManager.primaryTextColor)
                        .padding(.horizontal, 2)
                    
                    // Unit (denominator) button
                    Button(action: {
                        isEditingTimeSignatureUnit = true
                        isEditingTimeSignatureBeats = false
                    }) {
                        Text("\(projectViewModel.timeSignatureUnit)")
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundColor(themeManager.primaryTextColor)
                            .frame(width: 30, height: 24)
                            .background(themeManager.tertiaryBackgroundColor.opacity(0.3))
                            .cornerRadius(4)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .popover(isPresented: $isEditingTimeSignatureUnit, arrowEdge: .bottom) {
                        VStack(spacing: 0) {
                            ForEach([2, 4, 8, 16], id: \.self) { unit in
                                Button(action: {
                                    projectViewModel.timeSignatureUnit = unit
                                    isEditingTimeSignatureUnit = false
                                }) {
                                    Text("\(unit)")
                                        .frame(width: 100, height: 30)
                                        .foregroundColor(themeManager.primaryTextColor)
                                        .background(projectViewModel.timeSignatureUnit == unit ? 
                                                  themeManager.accentColor.opacity(0.2) : 
                                                  Color.clear)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.vertical, 5)
                        .background(themeManager.secondaryBackgroundColor)
                    }
                }
                .padding(.horizontal, 10)
                
                Divider()
                    .frame(height: 24)
                    .background(themeManager.secondaryBorderColor)
                
                // Transport controls
                HStack(spacing: 16) {
                    // Rewind button
                    Button(action: {
                        projectViewModel.rewind()
                    }) {
                        Image(systemName: "backward.fill")
                            .font(.title2)
                            .foregroundColor(themeManager.primaryTextColor)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .help("Rewind to beginning")
                    
                    // Play/Pause button
                    Button(action: {
                        projectViewModel.togglePlayback()
                    }) {
                        Image(systemName: projectViewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title)
                            .foregroundColor(themeManager.primaryTextColor)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .help("Play/Pause")
                    
                    // Record button
                    Button(action: {
                        // Record action (UI only)
                    }) {
                        Image(systemName: "record.circle")
                            .font(.title2)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .help("Record")
                    
                    // Loop button
                    Button(action: {
                        isLoopEnabled.toggle()
                    }) {
                        Image(systemName: "repeat")
                            .font(.subheadline)
                            .foregroundColor(isLoopEnabled ? .blue : themeManager.primaryTextColor)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .help("Loop playback")
                }
                .padding(.horizontal, 10)
            }
            
            Spacer()
            
            // Right group with system monitors
            HStack(spacing: 16) {
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
                
                // Memory usage indicator
                HStack(spacing: 4) {
                    Text("RAM:")
                        .font(.subheadline)
                        .foregroundColor(themeManager.primaryTextColor)
                    
                    Text(String(format: "%.0f MB", memoryUsage))
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(memoryUsage > 1024 ? .red : themeManager.primaryTextColor)
                        .frame(width: 65, alignment: .leading)
                }
                
                // Performance mode toggle
                Button(action: {
                    projectViewModel.togglePerformanceMode()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "gauge")
                            .font(.subheadline)
                            .foregroundColor(themeManager.primaryTextColor)
                        Text(projectViewModel.performanceModeName())
                            .font(.subheadline)
                            .foregroundColor(themeManager.primaryTextColor)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(themeManager.secondaryBackgroundColor)
                            .opacity(1.0)
                    )
                }
                .buttonStyle(BorderlessButtonStyle())
                .help("Toggle performance mode")
                
                // Theme toggle
                Button(action: {
                    themeManager.toggleTheme()
                }) {
                    Image(systemName: themeManager.currentTheme == .dark ? "sun.max" : "moon")
                       .foregroundColor(themeManager.primaryTextColor)
                }
                .buttonStyle(BorderlessButtonStyle())
                .help("Toggle between light and dark theme")
            }
            .padding(.horizontal, 10)
        }
        .padding(.vertical, 6)
        .frame(height: 44) // Further reduced height to match the new notch
        .background(themeManager.secondaryBackgroundColor)
        .border(themeManager.borderColor, width: 0.3)
        .environmentObject(ClickObserver.shared)
        .onReceive(NotificationCenter.default.publisher(for: ClickObserver.clickNotification)) { _ in
            // Handle outside clicks
            if isEditingTempo && !tempoFieldController.isEditing {
                isEditingTempo = false
            }
        }
        .onAppear {
            // Start a timer to update resource usage
            Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                // Simulate CPU usage fluctuation between 5% and 25%
                cpuUsage = Double.random(in: 5...25)
                // Simulate memory usage fluctuation
                memoryUsage = Double.random(in: 200...600)
            }
        }
    }
}

// A separate controller class to manage the text field outside of SwiftUI's rendering cycle
class TempoFieldController {
    var isEditing = false
    weak var textField: NSTextField?
    
    func setTextField(_ field: NSTextField) {
        self.textField = field
        
        // Focus the text field after it's set
        DispatchQueue.main.async {
            field.becomeFirstResponder()
            field.currentEditor()?.selectedRange = NSRange(location: 0, length: field.stringValue.count)
            self.isEditing = true
        }
    }
}

// A simple wrapper around NSHostingView to host our NSTextField
struct TempoFieldWrapper: NSViewRepresentable {
    let initialValue: String
    let themeManager: ThemeManager
    let controller: TempoFieldController
    let minValue: Int
    let maxValue: Int
    let onCommit: (String) -> Void
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.stringValue = initialValue
        textField.delegate = context.coordinator
        textField.isBordered = true
        textField.drawsBackground = true
        textField.backgroundColor = NSColor(themeManager.controlBackgroundColor)
        textField.textColor = NSColor(themeManager.primaryTextColor)
        textField.alignment = .center
        textField.font = NSFont.monospacedDigitSystemFont(ofSize: 16, weight: .regular)
        textField.bezelStyle = .roundedBezel
        textField.isBezeled = true
        textField.focusRingType = .none
        textField.toolTip = "Enter tempo (BPM) between \(minValue) and \(maxValue)"
        
        // Set border and corner radius
        textField.wantsLayer = true
        textField.layer?.borderWidth = 1
        textField.layer?.borderColor = NSColor(themeManager.accentColor).cgColor
        textField.layer?.cornerRadius = 4
        
        // Register the text field with the controller outside the view update cycle
        controller.setTextField(textField)
        
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        // Minimal updates to avoid view cycle issues
        nsView.backgroundColor = NSColor(themeManager.controlBackgroundColor)
        nsView.textColor = NSColor(themeManager.primaryTextColor)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller, onCommit: onCommit, minValue: minValue, maxValue: maxValue)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        let controller: TempoFieldController
        let onCommit: (String) -> Void
        let minValue: Int
        let maxValue: Int
        
        init(controller: TempoFieldController, onCommit: @escaping (String) -> Void, minValue: Int, maxValue: Int) {
            self.controller = controller
            self.onCommit = onCommit
            self.minValue = minValue
            self.maxValue = maxValue
        }
        
        // Control what characters can be entered - only numbers
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            return false // Return false to handle the command using the default implementation
        }
        
        // Filter input to only allow numbers
        func control(_ control: NSControl, textShouldBeginEditing fieldEditor: NSText) -> Bool {
            return true
        }
        
        func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
            if let textField = control as? NSTextField {
                // Validate that value is within range
                if let value = Int(textField.stringValue), value >= minValue && value <= maxValue {
                    return true // Value is acceptable
                } else {
                    // If value is out of range, show a warning and prevent ending edit
                    let alert = NSAlert()
                    alert.alertStyle = .warning
                    alert.messageText = "Invalid Tempo Value"
                    alert.informativeText = "Please enter a tempo between \(minValue) and \(maxValue) BPM."
                    alert.addButton(withTitle: "OK")
                    
                    // Play alert sound
                    NSSound.beep()
                    
                    // Show the alert as sheet
                    if let window = textField.window {
                        alert.beginSheetModal(for: window) { _ in
                            // Re-select the text for editing once alert is dismissed
                            textField.becomeFirstResponder()
                        }
                    } else {
                        // Fallback to running alert modally if no window
                        alert.runModal()
                    }
                    
                    // Ensure focus stays in the text field
                    textField.becomeFirstResponder()
                    return false
                }
            }
            return true
        }
        
        // This is called whenever the text changes
        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else { return }
            
            // Filter out any non-numeric characters
            let filteredText = textField.stringValue.filter { "0123456789".contains($0) }
            
            // If the text changed (non-numeric characters were filtered out), update the field
            if filteredText != textField.stringValue {
                textField.stringValue = filteredText
            }
            
            // Don't let the value exceed maxValue in length
            let maxValueString = String(maxValue)
            if filteredText.count > maxValueString.count {
                textField.stringValue = String(filteredText.prefix(maxValueString.count))
            }
            
            // If a value exceeds maxValue, cap it at maxValue
            if let value = Int(textField.stringValue), value > maxValue {
                textField.stringValue = String(maxValue)
            }
        }
        
        func controlTextDidEndEditing(_ notification: Notification) {
            if let textField = notification.object as? NSTextField {
                // Get the numeric value
                let numericValue = textField.stringValue.filter { "0123456789".contains($0) }
                
                // If empty or zero, default to minimum value
                if numericValue.isEmpty || numericValue == "0" {
                    textField.stringValue = String(minValue)
                    onCommit(String(minValue))
                } else {
                    // Make sure value is within range
                    if let value = Int(numericValue) {
                        if value < minValue {
                            onCommit(String(minValue))
                        } else if value > maxValue {
                            onCommit(String(maxValue))
                        } else {
                            onCommit(numericValue)
                        }
                    } else {
                        // If not valid, use minimum value
                        onCommit(String(minValue))
                    }
                }
                
                controller.isEditing = false
            }
        }
    }
}

/// A view that displays the current playback position in time format (minutes:seconds)
struct TimePositionDisplayView: View {
    @ObservedObject var projectViewModel: ProjectViewModel
    @State private var displayedTimePosition: String = "0:00"
    @State private var updateTimer: Timer? = nil
    
    var body: some View {
        Text(displayedTimePosition)
            .font(.system(.caption, design: .monospaced))
            .foregroundColor(Color.primary)
            .onAppear {
                // Initialize with current position
                displayedTimePosition = formatTimePosition(projectViewModel.currentBeat, tempo: projectViewModel.tempo)
                
                // Start a timer that updates the display
                startUpdateTimer()
            }
            .onDisappear {
                // Clean up timer when view disappears
                updateTimer?.invalidate()
                updateTimer = nil
            }
            .onChange(of: projectViewModel.isPlaying) { _, isPlaying in
                if isPlaying {
                    // When playback starts, use a slower update rate
                    startUpdateTimer()
                } else {
                    // When playback stops, update immediately
                    displayedTimePosition = formatTimePosition(projectViewModel.currentBeat, tempo: projectViewModel.tempo)
                    startUpdateTimer(frequency: 10) // 10 Hz when not playing
                }
            }
    }
    
    private func startUpdateTimer(frequency: Double = 5) {
        // Cancel any existing timer
        updateTimer?.invalidate()
        
        // Create a new timer that updates at the specified frequency
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0/frequency, repeats: true) { _ in
            // Update the displayed position
            displayedTimePosition = formatTimePosition(projectViewModel.currentBeat, tempo: projectViewModel.tempo)
        }
    }
    
    // Convert beats to minutes:seconds.milliseconds format
    private func formatTimePosition(_ beats: Double, tempo: Double) -> String {
        // Convert beats to seconds based on tempo
        let secondsPerBeat = 60.0 / tempo
        let totalSeconds = beats * secondsPerBeat
        
        let minutes = Int(totalSeconds) / 60
        let seconds = Int(totalSeconds) % 60
        
        return String(format: "%d:%02d", minutes, seconds)
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
