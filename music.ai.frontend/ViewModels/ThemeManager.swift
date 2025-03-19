import SwiftUI
import Combine

/// Theme options available in the application
enum ThemeOption: String, CaseIterable, Identifiable {
    case light = "Light"
    case dark = "Dark"
    
    var id: String { self.rawValue }
}

/// ThemeManager handles the application's color scheme and provides colors for UI components
class ThemeManager: ObservableObject {
    // Published properties will trigger UI updates when changed
    @Published var currentTheme: ThemeOption = .light
    
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
    }
    
    // Change the theme and save the preference
    func setTheme(_ theme: ThemeOption) {
        currentTheme = theme
        themeChangeIdentifier = UUID() // Generate new identifier to force UI updates
        UserDefaults.standard.set(theme.rawValue, forKey: "appTheme")
    }
    
    // Toggle between light and dark themes
    func toggleTheme() {
        currentTheme = currentTheme == .light ? .dark : .light
        themeChangeIdentifier = UUID() // Generate new identifier to force UI updates
        UserDefaults.standard.set(currentTheme.rawValue, forKey: "appTheme")
    }
    
    // MARK: - Color Properties
    
    // Accent color for selections and highlights
    var accentColor: Color {
        switch currentTheme {
        case .light:
            return Color.blue
        case .dark:
            return Color.blue.opacity(0.8)
        }
    }
    
    // Background colors
    var backgroundColor: Color {
        switch currentTheme {
        case .light:
            return Color(white: 0.9)
        case .dark:
            return Color(white: 0.2)
        }
    }
    
    var secondaryBackgroundColor: Color {
        switch currentTheme {
        case .light:
            return Color(white: 0.95).opacity(0.8)
        case .dark:
            return Color(white: 0.25)
        }
    }
    
    var tertiaryBackgroundColor: Color {
        switch currentTheme {
        case .light:
            return Color(white: 0.85)
        case .dark:
            return Color(white: 0.3)
        }
    }
    
    // Background color specifically for controls like text fields
    var controlBackgroundColor: Color {
        switch currentTheme {
        case .light:
            return Color(white: 1.0) // White in light mode
        case .dark:
            return Color(white: 0.15) // Darker in dark mode
        }
    }
    
    // Border colors
    var borderColor: Color {
        switch currentTheme {
        case .light:
            return Color.black
        case .dark:
            return Color(white: 0.6)
        }
    }
    
    var secondaryBorderColor: Color {
        switch currentTheme {
        case .light:
            return Color.gray.opacity(0.7)
        case .dark:
            return Color(white: 0.45).opacity(0.7)
        }
    }
    
    // Text colors
    var primaryTextColor: Color {
        switch currentTheme {
        case .light:
            return Color.black
        case .dark:
            return Color.white
        }
    }
    
    var secondaryTextColor: Color {
        switch currentTheme {
        case .light:
            return Color(white: 0.3)
        case .dark:
            return Color(white: 0.8)
        }
    }
    
    // Grid colors
    var gridColor: Color {
        switch currentTheme {
        case .light:
            return Color.black.opacity(0.3)
        case .dark:
            return Color.white.opacity(0.3)
        }
    }
    
    var secondaryGridColor: Color {
        switch currentTheme {
        case .light:
            return Color.gray.opacity(0.2)
        case .dark:
            return Color.white.opacity(0.15)
        }
    }
    
    var tertiaryGridColor: Color {
        switch currentTheme {
        case .light:
            return Color.gray.opacity(0.1)
        case .dark:
            return Color.white.opacity(0.08)
        }
    }
    
    // New property for grid lines
    var gridLineColor: Color {
        switch currentTheme {
        case .light:
            return Color.black.opacity(0.4)
        case .dark:
            return Color.white.opacity(0.4)
        }
    }
    
    // Background color specifically for the ruler
    var rulerBackgroundColor: Color {
        switch currentTheme {
        case .light:
            // Darker than tertiaryBackgroundColor in light mode
            return Color(white: 0.7)
        case .dark:
            // Lighter than tertiaryBackgroundColor in dark mode
            return Color(white: 0.35)
        }
    }
    
    // Alternating grid section color for visual distinction
    var alternatingGridSectionColor: Color {
        switch currentTheme {
        case .light:
            // Reduced contrast in light mode (was 0.75 opacity 0.9)
            return Color(white: 0.80).opacity(0.8)
        case .dark:
            // Reduced contrast in dark mode (was 0.23 opacity 0.6)
            return Color(white: 0.30).opacity(0.3)
        }
    }
    
    // Determine if current theme is dark mode
    var isDarkMode: Bool {
        return currentTheme == .dark
    }
} 
