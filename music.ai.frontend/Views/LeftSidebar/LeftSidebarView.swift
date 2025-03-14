import SwiftUI

struct LeftSidebarView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Project Browser")
                .font(.headline)
                .padding()
                .foregroundColor(themeManager.primaryTextColor)
            
            ZStack {
                // Background for the list
                themeManager.secondaryBackgroundColor
                    .ignoresSafeArea()
                
                List {
                    Section(header: Text("Tracks")
                        .foregroundColor(themeManager.secondaryTextColor)) {
                        Text("Audio Track 1")
                            .foregroundColor(themeManager.primaryTextColor)
                            .listRowBackground(themeManager.secondaryBackgroundColor)
                        Text("MIDI Track 1")
                            .foregroundColor(themeManager.primaryTextColor)
                            .listRowBackground(themeManager.secondaryBackgroundColor)
                    }
                    
                    Section(header: Text("Samples")
                        .foregroundColor(themeManager.secondaryTextColor)) {
                        Text("Drums")
                            .foregroundColor(themeManager.primaryTextColor)
                            .listRowBackground(themeManager.secondaryBackgroundColor)
                        Text("Bass")
                            .foregroundColor(themeManager.primaryTextColor)
                            .listRowBackground(themeManager.secondaryBackgroundColor)
                        Text("Synths")
                            .foregroundColor(themeManager.primaryTextColor)
                            .listRowBackground(themeManager.secondaryBackgroundColor)
                    }
                }
                .listStyle(SidebarListStyle())
                .scrollContentBackground(.hidden)
            }
            .border(themeManager.secondaryBorderColor, width: 0.5)
        }
        .frame(width: 220)
        .background(themeManager.secondaryBackgroundColor)
        // .border(themeManager.borderColor, width: 1)
    }
}

#Preview {
    LeftSidebarView()
        .environmentObject(ThemeManager())
} 