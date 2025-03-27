import SwiftUI
import Combine

/// Theme options available in the application
enum ThemeOption: String, CaseIterable, Identifiable, Codable {
    case light = "Light"
    case lightGrey = "Light Grey"
    case dark = "Dark"
    case black = "Black"
    
    var id: String { self.rawValue }
}

/// ThemeManager handles the application's color scheme and provides colors for UI components
class ThemeManager: ObservableObject {
    // Published properties will trigger UI updates when changed
    @Published var currentTheme: ThemeOption = .light
    @Published var customPlayheadColor: Color? = nil
    
    // Add a UUID that changes whenever the theme changes
    // This helps force SwiftUI Canvas components to redraw
    @Published private(set) var themeChangeIdentifier = UUID()
    
    // Store the theme preference in UserDefaults
    init() {
        // Load saved theme if available
        if let savedTheme = UserDefaults.standard.string(forKey: "appTheme"),
           let theme = ThemeOption(rawValue: savedTheme) {
            currentTheme = theme
        }
        
        // Load saved playhead color if available
        if let colorData = UserDefaults.standard.data(forKey: "playheadColor") {
            do {
                let color = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: colorData)
                customPlayheadColor = Color(color ?? NSColor.black)
            } catch {
                print("Failed to load playhead color: \(error)")
            }
        }
    }
    
    // Change the theme and save the preference
    func setTheme(_ theme: ThemeOption) {
        currentTheme = theme
        
        // Reset custom playhead color to ensure it uses theme-specific color
        customPlayheadColor = nil
        
        // Remove stored custom playhead color from UserDefaults
        UserDefaults.standard.removeObject(forKey: "playheadColor")
        
        themeChangeIdentifier = UUID() // Generate new identifier to force UI updates
        UserDefaults.standard.set(theme.rawValue, forKey: "appTheme")
    }
    
    // Set and save custom playhead color
    func setPlayheadColor(_ color: Color) {
        customPlayheadColor = color
        themeChangeIdentifier = UUID() // Force UI updates
        
        // Save color to UserDefaults
        let nsColor = NSColor(color)
        do {
            let colorData = try NSKeyedArchiver.archivedData(withRootObject: nsColor, requiringSecureCoding: false)
            UserDefaults.standard.set(colorData, forKey: "playheadColor")
        } catch {
            print("Failed to save playhead color: \(error)")
        }
    }
    
    // Toggle between light and dark themes
    func toggleTheme() {
        currentTheme = currentTheme == .light ? .dark : .light
        
        // Reset custom playhead color to ensure it uses theme-specific color
        customPlayheadColor = nil
        
        // Remove stored custom playhead color from UserDefaults
        UserDefaults.standard.removeObject(forKey: "playheadColor")
        
        themeChangeIdentifier = UUID() // Generate new identifier to force UI updates
        UserDefaults.standard.set(currentTheme.rawValue, forKey: "appTheme")
    }
    
    // MARK: - Color Properties
    
    // Accent color for selections and highlights
    var accentColor: Color {
        switch currentTheme {
        case .light, .lightGrey:
            return Color.blue
        case .dark, .black:
            return Color.blue.opacity(0.8)
        }
    }
    
    // Background colors
    var backgroundColor: Color {
        switch currentTheme {
        case .light:
            return Color(white: 0.9)
        case .lightGrey:
            return Color(white: 0.75)
        case .dark:
            return Color(white: 0.2)
        case .black:
            return Color(white: 0.1)
        }
    }
    
    var secondaryBackgroundColor: Color {
        switch currentTheme {
        case .light:
            return Color(white: 0.95).opacity(0.8)
        case .lightGrey:
            return Color(white: 0.8)
        case .dark:
            return Color(white: 0.25)
        case .black:
            return Color(white: 0.15)
        }
    }
    
    var tertiaryBackgroundColor: Color {
        switch currentTheme {
        case .light:
            return Color(white: 0.85)
        case .lightGrey:
            return Color(white: 0.7)
        case .dark:
            return Color(white: 0.3)
        case .black:
            return Color(white: 0.2)
        }
    }
    
    // Background color specifically for controls like text fields
    var controlBackgroundColor: Color {
        switch currentTheme {
        case .light:
            return Color(white: 1.0)
        case .lightGrey:
            return Color(white: 0.85)
        case .dark:
            return Color(white: 0.15)
        case .black:
            return Color(white: 0.12)
        }
    }
    
    // Border colors
    var borderColor: Color {
        switch currentTheme {
        case .light:
            return Color.black
        case .lightGrey:
            return Color(white: 0.2)
        case .dark:
            return Color(white: 0.6)
        case .black:
            return Color(white: 0.7)
        }
    }
    
    var secondaryBorderColor: Color {
        switch currentTheme {
        case .light:
            return Color.gray.opacity(0.7)
        case .lightGrey:
            return Color(white: 0.3).opacity(0.7)
        case .dark:
            return Color(white: 0.45).opacity(0.7)
        case .black:
            return Color(white: 0.5).opacity(0.7)
        }
    }
    
    // Text colors
    var primaryTextColor: Color {
        switch currentTheme {
        case .light:
            return Color.black
        case .lightGrey:
            return Color.black
        case .dark, .black:
            return Color.white
        }
    }
    
    var secondaryTextColor: Color {
        switch currentTheme {
        case .light:
            return Color(white: 0.3)
        case .lightGrey:
            return Color(white: 0.2)
        case .dark:
            return Color(white: 0.8)
        case .black:
            return Color(white: 0.9)
        }
    }
    
    // Grid colors
    var gridColor: Color {
        switch currentTheme {
        case .light:
            return Color.black.opacity(0.3)
        case .lightGrey:
            return Color.black.opacity(0.25)
        case .dark:
            return Color.white.opacity(0.3)
        case .black:
            return Color.white.opacity(0.35)
        }
    }
    
    var secondaryGridColor: Color {
        switch currentTheme {
        case .light:
            return Color.gray.opacity(0.2)
        case .lightGrey:
            return Color.black.opacity(0.15)
        case .dark:
            return Color.white.opacity(0.15)
        case .black:
            return Color.white.opacity(0.2)
        }
    }
    
    var tertiaryGridColor: Color {
        switch currentTheme {
        case .light:
            return Color.gray.opacity(0.1)
        case .lightGrey:
            return Color.black.opacity(0.08)
        case .dark:
            return Color.white.opacity(0.08)
        case .black:
            return Color.white.opacity(0.1)
        }
    }
    
    // New property for grid lines
    var gridLineColor: Color {
        switch currentTheme {
        case .light:
            return Color.black.opacity(0.4)
        case .lightGrey:
            return Color.black.opacity(0.35)
        case .dark:
            return Color.white.opacity(0.4)
        case .black:
            return Color.white.opacity(0.45)
        }
    }
    
    // Background color specifically for the ruler
    var rulerBackgroundColor: Color {
        switch currentTheme {
        case .light:
            return Color(white: 0.7)
        case .lightGrey:
            return Color(white: 0.5)
        case .dark:
            return Color(white: 0.35)
        case .black:
            return Color(white: 0.25)
        }
    }
    
    // Playhead color for timeline indicator
    var playheadColor: Color {
        // Return custom color if set, otherwise return theme-appropriate color
        if let customColor = customPlayheadColor {
            return customColor
        }
        
        // Default to theme-appropriate colors for contrast
        switch currentTheme {
        case .light, .lightGrey:
            return Color.black // Dark playhead for light mode
        case .dark, .black:
            return Color.white // Light playhead for dark mode
        }
    }
    
    // Alternating grid section color for visual distinction
    var alternatingGridSectionColor: Color {
        switch currentTheme {
        case .light:
            return Color(white: 0.80).opacity(0.8)
        case .lightGrey:
            return Color(white: 0.70).opacity(0.5)
        case .dark:
            return Color(white: 0.30).opacity(0.3)
        case .black:
            return Color(white: 0.20).opacity(0.3)
        }
    }
    
    // Determine if current theme is dark mode
    var isDarkMode: Bool {
        return currentTheme == .dark || currentTheme == .black
    }
} 
