import SwiftUI

/// View for changing the application theme
struct ThemeSettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Theme Settings")
                .font(.headline)
                .foregroundColor(themeManager.primaryTextColor)
            
            Divider()
                .background(themeManager.secondaryBorderColor)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Select Theme")
                    .font(.subheadline)
                    .foregroundColor(themeManager.primaryTextColor)
                
                // Custom theme picker buttons instead of using Picker
                HStack(spacing: 8) {
                    // Light theme button
                    Button(action: {
                        themeManager.setTheme(.light)
                    }) {
                        VStack {
                            Image(systemName: "sun.max.fill")
                                .font(.system(size: 24))
                            Text("Light")
                                .font(.caption)
                        }
                        .frame(width: 80, height: 60)
                        .foregroundColor(themeManager.currentTheme == .light ? .blue : themeManager.primaryTextColor)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(themeManager.currentTheme == .light ? 
                                     Color.blue.opacity(0.1) : themeManager.secondaryBackgroundColor)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(themeManager.currentTheme == .light ? Color.blue : themeManager.secondaryBorderColor, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Dark theme button
                    Button(action: {
                        themeManager.setTheme(.dark)
                    }) {
                        VStack {
                            Image(systemName: "moon.fill")
                                .font(.system(size: 24))
                            Text("Dark")
                                .font(.caption)
                        }
                        .frame(width: 80, height: 60)
                        .foregroundColor(themeManager.currentTheme == .dark ? .blue : themeManager.primaryTextColor)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(themeManager.currentTheme == .dark ? 
                                     Color.blue.opacity(0.1) : themeManager.secondaryBackgroundColor)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(themeManager.currentTheme == .dark ? Color.blue : themeManager.secondaryBorderColor, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.top, 8)
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 300, height: 200)
        .background(themeManager.backgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(themeManager.borderColor, lineWidth: 1)
        )
    }
}

#Preview {
    ThemeSettingsView()
        .environmentObject(ThemeManager())
} 