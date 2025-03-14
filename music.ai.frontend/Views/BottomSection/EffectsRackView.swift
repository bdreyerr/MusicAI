import SwiftUI

/// View for displaying and managing effects and instruments for the selected track
struct EffectsRackView: View {
    @ObservedObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingAddEffectMenu = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content area - changes based on selected track
            if let selectedTrack = projectViewModel.selectedTrack {
                // Track is selected - show its effects
                VStack(alignment: .leading, spacing: 8) {
                    // Track info header with selected track info and add button
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: selectedTrack.type.icon)
                                .foregroundColor(selectedTrack.effectiveColor)
                            
                            Text(selectedTrack.name)
                                .font(.headline)
                                .foregroundColor(themeManager.primaryTextColor)
                        }
                        
                        Spacer()
                        
                        // Add effect button
                        Button(action: {
                            showingAddEffectMenu = true
                        }) {
                            Label("Add Effect", systemImage: "plus")
                                .foregroundColor(themeManager.primaryTextColor)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .help("Add Effect")
                        .popover(isPresented: $showingAddEffectMenu) {
                            addEffectMenuContent(for: selectedTrack)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Horizontal effects list - fills available space
                    GeometryReader { geometry in
                        ScrollView(.horizontal, showsIndicators: true) {
                            HStack(alignment: .top, spacing: 12) {
                                // Instrument section (for MIDI tracks)
                                if selectedTrack.type == .midi {
                                    instrumentView(for: selectedTrack, height: geometry.size.height - 16)
                                }
                                
                                // Effects
                                if selectedTrack.effects.isEmpty && selectedTrack.type != .midi {
                                    Text("No effects added")
                                        .foregroundColor(themeManager.secondaryTextColor)
                                        .padding()
                                        .frame(width: 200, height: geometry.size.height - 16)
                                        .background(themeManager.tertiaryBackgroundColor.opacity(0.3))
                                        .cornerRadius(8)
                                } else {
                                    ForEach(selectedTrack.effects) { effect in
                                        effectView(for: effect, height: geometry.size.height - 16)
                                    }
                                }
                                
                                // Extra space at the end
                                Spacer()
                                    .frame(width: 20)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .frame(height: geometry.size.height)
                        }
                    }
                }
            } else {
                // No track selected
                VStack {
                    Spacer()
                    Text("No track selected")
                        .foregroundColor(themeManager.secondaryTextColor)
                    Spacer()
                }
            }
        }
        .background(themeManager.secondaryBackgroundColor)
        .border(themeManager.secondaryBorderColor, width: 0.5)
    }
    
    // View for the instrument (MIDI tracks only)
    private func instrumentView(for track: Track, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Instrument header
            HStack {
                Image(systemName: "music.note")
                    .foregroundColor(themeManager.primaryTextColor)
                
                Text("Instrument")
                    .font(.subheadline)
                    .foregroundColor(themeManager.primaryTextColor)
                
                Spacer()
            }
            
            // Current instrument or selector
            if let instrument = track.instrument {
                HStack {
                    Image(systemName: instrument.type.icon)
                        .foregroundColor(themeManager.primaryTextColor)
                    
                    Text(instrument.name)
                        .foregroundColor(themeManager.primaryTextColor)
                    
                    Spacer()
                    
                    // Button to change instrument
                    Button(action: {
                        // Show instrument selector
                    }) {
                        Text("Change")
                            .foregroundColor(themeManager.primaryTextColor)
                            .font(.caption)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            } else {
                // No instrument selected
                HStack {
                    Text("No instrument selected")
                        .foregroundColor(themeManager.secondaryTextColor)
                        .font(.caption)
                    
                    Spacer()
                    
                    // Button to add instrument
                    Button(action: {
                        // Add a default piano instrument
                        let pianoInstrument = Effect(type: .instrument, name: "Grand Piano")
                        projectViewModel.setInstrumentForSelectedTrack(pianoInstrument)
                    }) {
                        Text("Add")
                            .foregroundColor(themeManager.primaryTextColor)
                            .font(.caption)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 200, height: height)
        .background(themeManager.tertiaryBackgroundColor.opacity(0.3))
        .cornerRadius(8)
    }
    
    // View for a single effect
    private func effectView(for effect: Effect, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Effect header
            HStack {
                Image(systemName: effect.type.icon)
                    .foregroundColor(themeManager.primaryTextColor)
                
                Text(effect.name)
                    .font(.subheadline)
                    .foregroundColor(themeManager.primaryTextColor)
                
                Spacer()
                
                // Toggle to enable/disable the effect
                Toggle("", isOn: Binding(
                    get: { effect.isEnabled },
                    set: { newValue in
                        var updatedEffect = effect
                        updatedEffect.isEnabled = newValue
                        projectViewModel.updateEffectOnSelectedTrack(updatedEffect)
                    }
                ))
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle())
                .scaleEffect(0.8)
                
                // Remove effect button
                Button(action: {
                    projectViewModel.removeEffectFromSelectedTrack(effectId: effect.id)
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(themeManager.secondaryTextColor)
                        .font(.caption)
                }
                .buttonStyle(BorderlessButtonStyle())
                .help("Remove Effect")
            }
            
            // Effect parameters (if any)
            if !effect.parameters.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(effect.parameters.keys.sorted()), id: \.self) { paramName in
                            if let value = effect.parameters[paramName] {
                                HStack {
                                    Text(formatParameterName(paramName))
                                        .font(.caption)
                                        .foregroundColor(themeManager.secondaryTextColor)
                                        .frame(width: 70, alignment: .leading)
                                    
                                    Slider(value: Binding(
                                        get: { value },
                                        set: { newValue in
                                            var updatedEffect = effect
                                            updatedEffect.parameters[paramName] = newValue
                                            projectViewModel.updateEffectOnSelectedTrack(updatedEffect)
                                        }
                                    ), in: parameterRange(for: paramName))
                                    .frame(width: 80)
                                    
                                    Text(formatParameterValue(paramName, value))
                                        .font(.caption)
                                        .foregroundColor(themeManager.secondaryTextColor)
                                        .frame(width: 40, alignment: .trailing)
                                }
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 220, height: height)
        .background(themeManager.tertiaryBackgroundColor.opacity(0.3))
        .cornerRadius(8)
    }
    
    // Content for the add effect menu
    private func addEffectMenuContent(for track: Track) -> some View {
        let compatibleEffects = projectViewModel.compatibleEffectTypesForSelectedTrack()
        
        return VStack(alignment: .leading, spacing: 8) {
            Text("Add Effect")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 8)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(compatibleEffects, id: \.self) { effectType in
                        Button(action: {
                            // Add the selected effect
                            let newEffect = Effect(type: effectType)
                            projectViewModel.addEffectToSelectedTrack(newEffect)
                            showingAddEffectMenu = false
                        }) {
                            HStack {
                                Image(systemName: effectType.icon)
                                    .foregroundColor(themeManager.primaryTextColor)
                                Text(effectType.name)
                                    .foregroundColor(themeManager.primaryTextColor)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .contentShape(Rectangle())
                        .background(Color.clear)
                        .onHover { hovering in
                            if hovering {
                                NSCursor.pointingHand.set()
                            } else {
                                NSCursor.arrow.set()
                            }
                        }
                    }
                }
            }
            .frame(width: 200, height: min(CGFloat(compatibleEffects.count) * 36, 200))
        }
        .padding(.bottom, 8)
    }
    
    // Helper function to format parameter names
    private func formatParameterName(_ name: String) -> String {
        // Convert camelCase to Title Case with spaces
        let withSpaces = name.replacingOccurrences(of: "([A-Z])", with: " $1", options: .regularExpression)
        return withSpaces.prefix(1).uppercased() + withSpaces.dropFirst()
    }
    
    // Helper function to format parameter values
    private func formatParameterValue(_ name: String, _ value: Double) -> String {
        if name.contains("gain") || name.contains("threshold") {
            return String(format: "%.1f dB", value)
        } else if name.contains("time") {
            return String(format: "%.2f s", value)
        } else if name.contains("cutoff") {
            return String(format: "%.0f Hz", value)
        } else if name.contains("ratio") {
            return String(format: "%.1f:1", value)
        } else if name.contains("mix") || name.contains("feedback") || name.contains("resonance") {
            return String(format: "%.0f%%", value * 100)
        } else {
            return String(format: "%.2f", value)
        }
    }
    
    // Helper function to determine parameter range
    private func parameterRange(for name: String) -> ClosedRange<Double> {
        if name.contains("gain") {
            return -24.0...24.0
        } else if name.contains("threshold") {
            return -60.0...0.0
        } else if name.contains("ratio") {
            return 1.0...20.0
        } else if name.contains("attack") {
            return 0.1...100.0
        } else if name.contains("release") {
            return 10.0...1000.0
        } else if name.contains("time") {
            return 0.01...2.0
        } else if name.contains("cutoff") {
            return 20.0...20000.0
        } else if name.contains("mix") || name.contains("feedback") || name.contains("resonance") {
            return 0.0...1.0
        } else {
            return 0.0...1.0
        }
    }
}

// Make EffectType conform to Hashable for use in ForEach
extension EffectType: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
    
    static func == (lhs: EffectType, rhs: EffectType) -> Bool {
        return lhs.name == rhs.name
    }
}

#Preview {
    EffectsRackView(projectViewModel: ProjectViewModel())
        .environmentObject(ThemeManager())
        .frame(height: 200)
} 