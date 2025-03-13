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
        UserDefaults.standard.set(theme.rawValue, forKey: "appTheme")
    }
    
    // Toggle between light and dark themes
    func toggleTheme() {
        currentTheme = currentTheme == .light ? .dark : .light
        UserDefaults.standard.set(currentTheme.rawValue, forKey: "appTheme")
    }
    
    // MARK: - Color Properties
    
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
            return Color.gray.opacity(0.5)
        case .dark:
            return Color(white: 0.5).opacity(0.5)
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
} 
