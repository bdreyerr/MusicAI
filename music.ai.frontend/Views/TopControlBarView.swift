import SwiftUI

struct TopControlBarView: View {
    @ObservedObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 16) {
            // Transport controls
            HStack(spacing: 8) {
                Button(action: {
                    projectViewModel.rewind()
                }) {
                    Image(systemName: "backward.fill")
                        .font(.title3)
                        .foregroundColor(themeManager.primaryTextColor)
                }
                
                Button(action: {
                    projectViewModel.togglePlayback()
                }) {
                    Image(systemName: projectViewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .foregroundColor(themeManager.primaryTextColor)
                }
                
                Button(action: {
                    // Record action
                }) {
                    Image(systemName: "record.circle")
                        .font(.title3)
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal)
            
            Divider()
                .frame(height: 24)
                .background(themeManager.secondaryBorderColor)
            
            // Tempo control
            HStack {
                Text("Tempo:")
                    .font(.subheadline)
                    .foregroundColor(themeManager.primaryTextColor)
                
                TextField("", value: $projectViewModel.tempo, formatter: NumberFormatter())
                    .frame(width: 50)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .foregroundColor(themeManager.primaryTextColor)
                
                Text("BPM")
                    .font(.subheadline)
                    .foregroundColor(themeManager.primaryTextColor)
            }
            
            Divider()
                .frame(height: 24)
                .background(themeManager.secondaryBorderColor)
            
            // Time signature
            HStack {
                Text("Time Signature:")
                    .font(.subheadline)
                    .foregroundColor(themeManager.primaryTextColor)
                
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
            }
            
            Spacer()
            
            // Project info
            Text("Project: My New Track")
                .font(.headline)
                .foregroundColor(themeManager.primaryTextColor)
                .padding(.trailing)
        }
        .padding(.vertical, 8)
        .frame(height: 50)
        .background(themeManager.secondaryBackgroundColor)
        .border(themeManager.borderColor, width: 1)
    }
}

#Preview {
    TopControlBarView(projectViewModel: ProjectViewModel())
        .environmentObject(ThemeManager())
} 
